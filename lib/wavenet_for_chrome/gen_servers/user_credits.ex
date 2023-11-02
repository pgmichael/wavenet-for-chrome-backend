require Logger

# TODO(mike): Payment logic could be extracted to a separate module
# TODO(mike): Timeout logic could be extracted to a separate module
# TODO(mike): Rate limiting logic could be extracted to a separate module

defmodule WavenetForChrome.UserCredits do
  alias WavenetForChrome.Invoice
  alias WavenetForChrome.{Insight, User, Repo}
  alias WavenetForChromeWeb.TextToSpeech
  use GenServer

  # Shut down the server after 120 seconds of inactivity since usage is
  # transient and we don't want to keep the server running indefinitely.
  @idle_timeout 120_000

  # Rate limit to 50 requests per second to avoid a single user from
  # depleting their credits too quickly, and hogging our API quotas
  @rate_limit 50
  @replenish_interval div(1_000, @rate_limit)

  # Client

  def start_link(user_id, user_ip_address) do
    GenServer.start_link(__MODULE__, %{user_id: user_id, user_ip_address: user_ip_address},
      name: {:global, user_id}
    )
  end

  def acquire_pid(user_id, ip_address) do
    existing_process = GenServer.whereis({:global, user_id})

    existing_process ||
      case start_link(user_id, ip_address) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end
  end

  def charge(pid, params) do
    # 120 seconds is the maximum time we allow for a request to complete
    GenServer.call(pid, {:charge, params}, 120_000)
  end

  # Server

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

  def handle_call({:charge, params}, _, state) do
    Process.send_after(self(), :idle_timeout, @idle_timeout)

    if state.tokens <= 0 do
      Logger.warning("Rate limit exceeded for user '#{state.user_id}'.")

      Process.sleep(@replenish_interval)
    end

    cost = TextToSpeech.calculate_cost!(params)

    user =
      Repo.get_by!(User, id: state.user_id)
      |> ensure_user_has_enough_credits!(cost)

    case TextToSpeech.synthesize!(params, System.get_env("TTS_API_KEY")) do
      {:ok, body} ->
        User.adjust_credits!(user, -cost)
        Insight.track(params, state.user_ip_address, state.user_id)
        {:reply, {:ok, body}, %{state | tokens: state.tokens - 1}}

      {:error, body} ->
        {:reply, {:error, body}, %{state | tokens: state.tokens - 1}}
    end
  end

  defp ensure_user_has_enough_credits!(%User{credits: credits} = user, cost) when credits >= cost,
    do: user

  defp ensure_user_has_enough_credits!(user, _cost) do
    charge_result =
      Stripe.Charge.create(%{
        "amount" => 975,
        "currency" => "usd",
        "customer" => user.stripe_customer_id
      })

    case charge_result do
      {:ok, charge} ->
        Invoice.create!(user, charge)
        User.adjust_credits!(user, charge.amount * 10_000)

      {:error, error} ->
        throw(error)
    end
  end
end
