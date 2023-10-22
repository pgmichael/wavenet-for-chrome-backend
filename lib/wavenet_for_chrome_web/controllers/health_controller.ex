require Logger

defmodule WavenetForChromeWeb.HealthController do
  use WavenetForChromeWeb, :controller
  alias WavenetForChrome.Repo

  def index(conn, _params) do
    {uptime, _} = :erlang.statistics(:wall_clock)
    {_, result} = Repo.query("SELECT version()")

    data = %{
      status: "ok",
      uptime: uptime,
      database: hd(hd(result.rows)),
      runtime: "Elixir #{System.version()}"
    }

    json(conn, data)
  end
end
