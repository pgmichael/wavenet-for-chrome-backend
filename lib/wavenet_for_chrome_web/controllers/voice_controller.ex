require Logger

defmodule WavenetForChromeWeb.VoiceController do
  use WavenetForChromeWeb, :controller

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
    url = "#{System.get_env("TTS_API_URL")}/voices?key=#{System.get_env("TTS_API_KEY")}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        voices = Jason.decode!(body)["voices"]
        Logger.info("Fetched #{length(voices)} voices from Google")
        Cachex.put(:default, "voices", voices, ttl: :timer.minutes(30))
        ok(conn, voices)

      {:error, error} ->
        Sentry.capture_message("Failed to fetch voices from Google: #{inspect(error)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{errors: "Unable to fetch voices"})
    end
  end
end
