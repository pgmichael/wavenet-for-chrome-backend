defmodule WavenetForChromeWeb.RootController do
  use WavenetForChromeWeb, :controller

  def index(conn, _params) do
    ok(conn, %{message: "Welcome to Wavenet for Chrome API"})
  end
end
