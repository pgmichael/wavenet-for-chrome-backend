require Logger

defmodule WavenetForChrome.UserCreditsServer do
  alias WavenetForChrome.Insight
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
        |> decrement_credits(cost)
        |> synthesize(params)
      end)

    case response do
      {:ok, body} ->
        track(user_id, user_ip_address, params)
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
        # TODO(mike): Should be a constant
        "amount" => 975,
        "currency" => "usd",
        "customer" => user.stripe_customer_id
      })

    case result do
      {:ok, charge} ->
        User.create_invoice_from_charge(user, charge)
        |> User.adjust_credits(charge.amount * 1000)

      {:error, _} ->
        # TODO(mike): Sentry
        {:error, "Failed to charge user"}
    end
  end

  # TODO(mike): Sentry when this fails
  defp track(user_id, user_ip_address, params) do
    changeset =
      Insight.changeset(%Insight{}, %{
        user_id: user_id,
        user_ip_address: user_ip_address,
        character_count: String.length(params["text"] || params["ssml"]),
        voice_name: params["voice_name"],
        voice_language_code: params["voice_language_code"],
        audio_pitch: params["audio_pitch"],
        audio_speaking_rate: params["audio_speaking_rate"],
        audio_volume_gain_db: params["audio_volume_gain_db"],
        audio_encoding: params["audio_encoding"],
        extension_version: params["extension_version"]
      })

    case Repo.insert(changeset) do
      {:error, error} -> Logger.error(inspect(error))
      _ -> :ok
    end
  end

  defp decrement_credits(user, cost) do
    user
    |> User.changeset(%{credits: user.credits - cost})
    |> Repo.update!()
  end

  defp synthesize(_user, params) do
    tts_api_url = System.get_env("TTS_API_URL")
    tts_api_key = System.get_env("GOOGLE_CLOUD_TEXT_TO_SPEECH_API_KEY")
    url = "#{tts_api_url}/text:synthesize?key=#{tts_api_key}"

    payload =
      Jason.encode!(%{
        audioConfig: %{
          audioEncoding: params["audio_encoding"],
          pitch: params["audio_pitch"],
          speakingRate: params["audio_speaking_rate"],
          volumeGainDb: params["audio_volume_gain_db"]
        },
        input: %{
          ssml: params["ssml"],
          text: params["text"]
        },
        voice: %{
          languageCode: params["voice_language_code"],
          name: params["voice_name"]
        }
      })

    headers = [
      {"content-type", "application/json; charset=utf-8"}
    ]

    respone = HTTPoison.post(url, payload, headers)
    Logger.info(inspect(respone))

    case respone do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 200..299 ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 400..599 ->
        {:error, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        # TODO(mike): Sentry
        IO.puts("HTTP request failed: #{reason}")

      _ ->
        # TODO(mike): Sentry
        IO.puts("Unexpected response")
    end
  end
end
