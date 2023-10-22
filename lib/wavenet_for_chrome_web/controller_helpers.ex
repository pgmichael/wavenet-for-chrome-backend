defmodule WavenetForChromeWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  alias WavenetForChrome.User
  alias WavenetForChrome.Repo

  @moduledoc """
  A module providing helper functions for controllers.

  These functions are available in all controllers.
  """

  def get_authorization_token(conn) do
    conn
    |> get_req_header("authorization")
    |> Enum.at(0)
    |> String.replace("Bearer ", "")
  end

  def generate_secret_key do
    key = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    "secret_key_#{key}"
  end

  def get_user_by_secret_key(conn, opts \\ []) do
    case Repo.get_by(User, secret_key: get_authorization_token(conn)) do
      nil ->
        if Keyword.get(opts, :return_nil, false) do
          nil
        else
          unauthorized(conn)
        end

      user ->
        user
    end
  end

  def handle_response(conn, status, data_or_errors) do
    conn
    |> put_status(status)
    |> json(data_or_errors)
  end

  def get_user_ip_address(conn) do
    forwarded_for =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()

    if forwarded_for do
      forwarded_for
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      conn.remote_ip
      |> :inet_parse.ntoa()
      |> to_string()
    end
  end

  def ok(conn, data \\ "ok"),
    do: handle_response(conn, :ok, data)

  def no_content(conn, data \\ "no_content"),
    do: handle_response(conn, :no_content, data)

  def created(conn, data \\ "created"),
    do: handle_response(conn, :created, data)

  def unauthorized(conn, error \\ %{}) do
    default_error = %{
      code: "unauthorized",
      message: "You are not authorized to perform this action"
    }

    handle_response(conn, :unauthorized, Map.merge(default_error, error))
  end

  def unprocessable_entity(conn, error \\ %{}) do
    default_error = %{
      code: "unprocessable_entity",
      message: "The request was well-formed but was unable to be followed due to semantic errors"
    }

    handle_response(conn, :unprocessable_entity, Map.merge(default_error, error))
  end

  def not_found(conn, error \\ %{}) do
    default_error = %{
      code: "not_found",
      message: "The requested resource could not be found"
    }

    handle_response(conn, :not_found, Map.merge(default_error, error))
  end

  def forbidden(conn, error \\ %{}) do
    default_error = %{
      code: "forbidden",
      message: "You are not authorized to perform this action"
    }

    handle_response(conn, :forbidden, Map.merge(default_error, error))
  end

  def bad_request(conn, error \\ %{}) do
    default_error = %{
      code: "bad_request",
      message: "The request could not be understood by the server due to malformed syntax"
    }

    handle_response(conn, :bad_request, Map.merge(default_error, error))
  end

  def internal_server_error(conn, error \\ %{}) do
    default_error = %{
      code: "internal_server_error",
      message:
        "The server encountered an unexpected condition that prevented it from fulfilling the request"
    }

    handle_response(conn, :internal_server_error, Map.merge(default_error, error))
  end
end
