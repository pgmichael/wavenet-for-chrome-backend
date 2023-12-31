require Logger

defmodule WavenetForChromeWeb.PaymentSessionController do
  use WavenetForChromeWeb, :controller
  alias WavenetForChrome.Repo
  alias WavenetForChrome.User

  @stripe_price_id System.get_env("STRIPE_PRICE_ID")

  def create(conn, _) do
    conn
    |> get_user_by_secret_key
    |> ensure_stripe_customer_for_user(conn)
    |> create_stripe_invoice(conn)
  end

  defp ensure_stripe_customer_for_user(user, conn) do
    case user.stripe_customer_id do
      nil -> create_stripe_customer(user, conn).id
      stripe_customer_id -> stripe_customer_id
    end
  end

  defp create_stripe_customer(user, conn) do
    result =
      Stripe.Customer.create(%{
        "email" => user.email,
        "name" => user.email,
        "description" => "Wavenet for Chrome user"
      })

    case result do
      {:ok, customer} ->
        user
        |> User.changeset(%{stripe_customer_id: customer.id})
        |> Repo.update()

        customer

      {:error, stripe_error} ->
        Sentry.capture_message("Failed to create stripe customer: #{inspect(stripe_error)}")
        internal_server_error(conn, %{message: "Failed to create stripe customer."})
    end
  end

  defp create_stripe_invoice(stripe_customer_id, conn) do
    result =
      Stripe.Invoice.create(%{
        "customer" => stripe_customer_id,
        "collection_method" => "send_invoice",
        "days_until_due" => 90,
        "currency" => "usd"
      })

    case result do
      {:ok, invoice} ->
        create_stripe_invoice_item(invoice, conn)

      {:error, stripe_error} ->
        Sentry.capture_message("Failed to create stripe invoice: #{inspect(stripe_error)}")
        internal_server_error(conn, %{message: "Failed to create stripe invoice."})
    end
  end

  defp create_stripe_invoice_item(invoice, conn) do
    result =
      Stripe.Invoiceitem.create(%{
        "invoice" => invoice.id,
        "customer" => invoice.customer,
        "price" => @stripe_price_id
      })

    case result do
      {:ok, _} ->
        finalize_stripe_invoice(invoice, conn)

      {:error, stripe_error} ->
        Sentry.capture_message("Failed to create stripe invoice item: #{inspect(stripe_error)}")
        internal_server_error(conn, %{message: "Failed to create stripe invoice item."})
    end
  end

  defp finalize_stripe_invoice(invoice, conn) do
    case Stripe.Invoice.finalize_invoice(invoice.id) do
      {:ok, invoice} ->
        expiry_date =
          DateTime.utc_now()
          |> DateTime.add(89, :day) # 90 days from now, minus 1 day for as a grace period for the user
          |> DateTime.to_iso8601()

        created(conn, %{
          id: invoice.id,
          hosted_invoice_url: invoice.hosted_invoice_url,
          expiry_date: expiry_date
        })

      {:error, stripe_error} ->
        Logger.error("Failed to finalize invoice: #{inspect(stripe_error)}")
        internal_server_error(conn, %{message: "Failed to finalize invoice."})
    end
  end

end
