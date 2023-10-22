require Logger

defmodule WavenetForChromeWeb.VoiceController do
  use WavenetForChromeWeb, :controller

  @tts_api_url System.get_env("TTS_API_URL")
  @google_cloud_text_to_speech_api_key System.get_env("GOOGLE_CLOUD_TEXT_TO_SPEECH_API_KEY")

  def index(conn, _params) do
    case Cachex.get(:default, "voices") do
      {:ok, voices} when is_list(voices) ->
        Logger.info("Returning #{length(voices)} voices from cache")
        json(conn, voices)

      _ ->
        Logger.info("Fetching voices from Google")
        fetch_voices(conn)
    end
  end

  defp fetch_voices(conn) do
    url = "#{@tts_api_url}/voices?key=#{@google_cloud_text_to_speech_api_key}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        voices = Jason.decode!(body)["voices"]
        Logger.info("Fetched #{length(voices)} voices from Google")
        Cachex.put(:default, "voices", voices, ttl: :timer.minutes(30))
        json(conn, %{data: voices})

      {:error, google_error} ->
        Logger.error("Failed to fetch voices: #{inspect(google_error)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: "Unable to fetch voices"})
    end
  end
end
