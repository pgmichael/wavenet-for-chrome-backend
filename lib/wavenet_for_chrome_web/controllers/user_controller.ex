require Logger

defmodule WavenetForChromeWeb.UserController do
  use WavenetForChromeWeb, :controller
  alias WavenetForChrome.Repo
  alias WavenetForChrome.User

  def index(conn, _) do
    case Repo.get_by(User, secret_key: get_authorization_token(conn)) do
      nil -> unauthorized(conn)
      user -> ok(conn, user)
    end
  end

  def create(conn, _) do
    conn
    |> get_authorization_token
    |> get_token_info(conn)
    |> cache_token_info()
    |> upsert_user(conn)
  end

  defp get_token_info(auth_token, conn) do
    case Cachex.get(:default, auth_token) do
      {:ok, token_info} when is_struct(token_info) ->
        Logger.info("Returning token info from cache")
        token_info

      _ ->
        Logger.info("Fetching token info from Google")
        get_token_info_from_google(auth_token, conn)
    end
  end

  defp get_token_info_from_google(auth_token, conn) do
    url = "https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=#{auth_token}"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> Jason.decode!(body)
      {:error, _} -> unauthorized(conn)
    end
  end

  defp cache_token_info(token_info) do
    {expires_in_seconds, _} = Integer.parse(token_info["expires_in"])
    expires_in_ms = expires_in_seconds * 1000 - 60 * 1000
    Cachex.put(:default, token_info["email"], token_info, ttl: expires_in_ms)

    token_info
  end

  defp upsert_user(token_info, conn) do
    changeset =
      User.changeset(%User{}, %{
        email: token_info["email"],
        secret_key: generate_secret_key()
      })

    case Repo.insert(changeset) do
      {:ok, user} ->
        Logger.info("Created user #{inspect(user)}")
        ok(conn, user)

      {:error, _} ->
        case Repo.get_by(User, email: token_info["email"]) do
          nil -> unprocessable_entity(conn)
          user -> ok(conn, user)
        end
    end
  end
end
