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
    invoices_result = Repo.all(from i in Invoice, where: i.user_id == ^user.id)

    case invoices_result do
      invoices when is_list(invoices) -> ok(conn, invoices)
      result -> throw("Unexpected invoices result '#{inspect(result)}'.")
    end
  end
end
