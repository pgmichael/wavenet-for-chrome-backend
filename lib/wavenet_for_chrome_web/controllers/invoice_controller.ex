defmodule WavenetForChromeWeb.InvoiceController do
  use WavenetForChromeWeb, :controller
  import Ecto.Query
  alias WavenetForChrome.Invoice
  alias WavenetForChrome.Repo

  def index(conn, _params) do
    conn
    |> get_user_by_secret_key()
    |> get_user_invoices(conn)
  end

  defp get_user_invoices(user, conn) do
    case Repo.all(from i in Invoice, where: i.user_id == ^user.id) do
      [] -> no_content(conn)
      invoices -> ok(conn, invoices)
    end
  end
end
