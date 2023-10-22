defmodule WavenetForChromeWeb.TextToSpeechService do
  alias WavenetForChrome.Insight
  alias WavenetForChrome.Repo

  @tts_api_url System.get_env("TTS_API_URL")
  @tts_api_key System.get_env("TTS_API_KEY")

  def synthesize(params, key) do
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

    url = "#{@tts_api_url}/text:synthesize?key=#{key || @tts_api_key}"
    response = HTTPoison.post(url, payload, headers)

    case response do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 200..299 ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 400..599 ->
        {:error, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Sentry.capture_exception(%RuntimeError{
          message: "Failed to synthesize audio: #{inspect(reason)}"
        })

        {:error, "Failed to synthesize audio"}

      _ ->
        Sentry.capture_exception(%RuntimeError{
          message: "Failed to synthesize audio. Unknown error."
        })

        {:error, "Failed to synthesize audio. Unknown error."}
    end
  end

  def track(user_id, user_ip_address, params) do
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
      {:error, error} ->
        # Swallow and send to Sentry since it's not critical to the user, but useful
        # for payment disputes
        Sentry.capture_exception(%RuntimeError{
          message: "Failed to track user: #{inspect(error)}"
        })

      _ ->
        :ok
    end
  end
end
