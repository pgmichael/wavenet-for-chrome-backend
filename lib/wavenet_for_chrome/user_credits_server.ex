require Logger

defmodule WavenetForChrome.UserCreditsServer do
  alias WavenetForChromeWeb.TextToSpeechService
  alias Hex.API.User
  alias WavenetForChrome.User
  alias WavenetForChrome.Repo
  use GenServer

  # Shut down the server after 120 seconds of inactivity since usage is
  # transient and we don't want to keep the server running indefinitely.
  @idle_timeout 120_000

  # Rate limit to 50 requests per second to avoid a single user from
  # depleting their credits too quickly, and hogging our API quotas
  @rate_limit 50
  @replenish_interval div(1_000, @rate_limit)

  @tts_api_key System.get_env("TTS_API_KEY")

  def start_link(user_id, user_ip_address) do
    GenServer.start_link(__MODULE__, %{user_id: user_id, user_ip_address: user_ip_address},
      name: {:global, user_id}
    )
  end

  def init(args) do
    Process.send_after(self(), :replenish_tokens, @replenish_interval)

    {:ok, %{user_id: args.user_id, user_ip_address: args.user_ip_address, tokens: @rate_limit}}
  end

  def handle_info(:replenish_tokens, %{tokens: tokens} = state) do
    new_tokens = min(tokens + 1, @rate_limit)
    Process.send_after(self(), :replenish_tokens, @replenish_interval)
    {:noreply, %{state | tokens: new_tokens}}
  end

  def handle_info(:idle_timeout, state) do
    {:stop, :normal, state}
  end

  def charge(pid, cost, params) do
    GenServer.call(pid, {:charge, cost, params})
  end

  def handle_call(
        {:charge, cost, params},
        _,
        %{user_id: user_id, tokens: tokens, user_ip_address: user_ip_address} = state
      ) do
    Process.send_after(self(), :idle_timeout, @idle_timeout)

    if tokens <= 0 do
      Logger.warning("Rate limit exceeded for user #{user_id}")
      Process.sleep(@replenish_interval)
    end

    user = Repo.get_by!(User, id: user_id)

    response =
      Repo.transaction(fn ->
        user
        |> top_up_credits(cost)
        |> User.adjust_credits(-cost)

        TextToSpeechService.synthesize(params, @tts_api_key)
      end)

    case response do
      {:ok, body} ->
        TextToSpeechService.track(user_id, user_ip_address, params)
        {:reply, body, %{state | tokens: tokens - 1}}

      {:error, body} ->
        {:reply, body, %{state | tokens: tokens - 1}}
    end
  end

  defp top_up_credits(user, cost) do
    case user.credits >= cost do
      true -> user
      false -> charge_user(user)
    end
  end

  defp charge_user(user) do
    result =
      Stripe.Charge.create(%{
        "amount" => 975,
        "currency" => "usd",
        "customer" => user.stripe_customer_id
      })

    case result do
      {:ok, charge} ->
        User.create_invoice_from_charge(user, charge)
        |> User.adjust_credits(charge.amount * 1000)

      {:error, error} ->
        Sentry.capture_exception(%RuntimeError{
          message: "Failed to charge user: #{inspect(error)}"
        })

        {:error, "Failed to charge user"}
    end
  end
end
