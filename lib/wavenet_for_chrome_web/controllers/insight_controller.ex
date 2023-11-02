defmodule WavenetForChromeWeb.InsightController do
  use WavenetForChromeWeb, :controller
  alias WavenetForChrome.Repo
  alias WavenetForChrome.Insight
  import Ecto.Query

  def index(conn, _params) do
    user = get_user_by_secret_key(conn)

    insights =
      Repo.all(
        from i in Insight,
          where: i.user_id == ^user.id,
          order_by: [desc: i.inserted_at],
          limit: 100
      )

    ok(conn, insights)
  end
end
