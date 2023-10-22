defmodule WavenetForChromeWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Cache the body of the request in the connection.

  This is useful since Stripe's `construct_event` function needs to consume the
  body of the request, but is stripped out by other ParseBody plugs.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
