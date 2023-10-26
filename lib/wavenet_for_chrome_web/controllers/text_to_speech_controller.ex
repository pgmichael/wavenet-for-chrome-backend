defmodule WavenetForChromeWeb.TextToSpeechController do
  alias WavenetForChrome.{Insight, UserCredits}
  alias WavenetForChromeWeb.TextToSpeech
  use WavenetForChromeWeb, :controller

  def synthesize(conn, params) do
    if has_provided_api_key?(params),
      do: synthesize_for_free_user(conn, params),
      else: synthesize_for_paid_user(conn, params)
  end

  defp synthesize_for_free_user(conn, params) do
    case TextToSpeech.synthesize!(params, params["key"]) do
      {:ok, body} ->
        Insight.track(params, get_user_ip_address(conn))
        ok(conn, body)

      {:error, body} ->
        unprocessable_entity(conn, body)
    end
  end

  defp synthesize_for_paid_user(conn, params) do
    user = get_user_by_secret_key(conn)
    user_ip_address = get_user_ip_address(conn)
    pid = UserCredits.acquire_pid(user.id, user_ip_address)

    case UserCredits.charge(pid, params) do
      {:ok, body} -> ok(conn, body)
      {:error, body} -> unprocessable_entity(conn, body)
    end
  end

  defp has_provided_api_key?(params) do
    Map.has_key?(params, "key")
  end
end
