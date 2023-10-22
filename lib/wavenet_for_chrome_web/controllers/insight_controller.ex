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

  def create(conn, params) do
    ip_address = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    user = get_user_by_secret_key(conn, return_nil: true)

    Map.merge(params, %{
      user_id: user |> get_in([:id]),
      ip_address: ip_address
    })

    changeset = Insight.changeset(%Insight{}, params)

    case Repo.insert(changeset) do
      {:ok, insight} ->
        conn
        |> put_status(:created)
        |> json(%{data: insight})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset})
    end
  end
end
