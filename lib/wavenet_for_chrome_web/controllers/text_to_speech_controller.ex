require Logger

defmodule WavenetForChromeWeb.TextToSpeechController do
  alias WavenetForChromeWeb.TextToSpeechService
  use WavenetForChromeWeb, :controller

  @pricing_table %{
    "standard" => 16,
    "wavenet" => 48,
    "neural2" => 48,
    "polyglot" => 48,
    "news" => 48,
    "studio" => 240
  }

  def synthesize(conn, params) do
    if Map.has_key?(params, "key") do
      case TextToSpeechService.synthesize(params, params["key"]) do
        {:ok, body} ->
          TextToSpeechService.track(nil, get_user_ip_address(conn), params)
          ok(conn, body)

        {:error, body} ->
          unprocessable_entity(conn, body)
      end
    else
      user = get_user_by_secret_key(conn)
      text_or_ssml = Map.get(params, "text") || Map.get(params, "ssml")
      cost = calculate_cost(params, String.length(text_or_ssml))
      user_ip_address = get_user_ip_address(conn)

      pid =
        GenServer.whereis({:global, user.id}) ||
          case WavenetForChrome.UserCreditsServer.start_link(user.id, user_ip_address) do
            {:ok, pid} -> pid
            {:error, {:already_started, pid}} -> pid
          end

      case WavenetForChrome.UserCreditsServer.charge(pid, cost, params) do
        {:ok, body} -> ok(conn, body)
        {:error, body} -> unprocessable_entity(conn, body)
      end
    end
  end

  defp calculate_cost(%{"voice_name" => voice_name}, character_count) do
    voice_type = voice_name |> String.split("-") |> Enum.at(2) |> String.downcase()
    character_count * @pricing_table[voice_type]
  end
end
