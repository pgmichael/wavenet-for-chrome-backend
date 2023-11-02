defmodule WavenetForChromeWeb.TextToSpeech do
  @tts_api_url System.get_env("TTS_API_URL")
  @tts_api_key System.get_env("TTS_API_KEY")
  @cost_per_character_by_voice_type %{
    "standard" => 16,
    "wavenet" => 48,
    "neural2" => 48,
    "polyglot" => 48,
    "news" => 48,
    "studio" => 240
  }

  def synthesize!(params, key) do
    url = "#{@tts_api_url}/text:synthesize?key=#{key || @tts_api_key}"
    body = encode_tts_request_body(params)
    headers = [{"content-type", "application/json; charset=utf-8"}]
    options = [timeout: 10_000, recv_timeout: 10_000]

    case HTTPoison.post(url, body, headers, options) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 200..299 ->
        {:ok, Poison.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
      when status_code in 400..599 ->
        {:error, Poison.decode!(body)}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Sentry.capture_message("Unexpected HTTPoison error '#{reason}'.")
        {:error, reason}

      response ->
        throw("Unexpected response '#{inspect(response)}'.")
    end
  end

  def get_character_count!(params) do
    text_to_synthesize = Map.get(params, "text") || Map.get(params, "ssml")

    if !text_to_synthesize do
      throw("Cannot calculate cost without text or ssml.")
    end

    String.length(text_to_synthesize)
  end

  def calculate_cost!(params) do
    voice_type =
      Map.get(params, "voice_name")
      |> String.split("-")
      |> Enum.at(2)
      |> String.downcase()

    cost_per_character = @cost_per_character_by_voice_type[voice_type]

    if !cost_per_character do
      throw("Cannot calculate cost for unkown voice type '#{voice_type}'.")
    end

    get_character_count!(params) * cost_per_character
  end

  defp encode_tts_request_body(params) do
    Jason.encode!(%{
      audioConfig: %{
        audioEncoding: params["audio_encoding"],
        pitch: params["audio_pitch"],
        speakingRate: params["audio_speaking_rate"],
        volumeGainDb: params["audio_volume_gain_db"],
        effectsProfileId: params["audio_profile"]
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
  end
end
