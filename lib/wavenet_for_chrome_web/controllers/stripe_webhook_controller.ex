require Logger

defmodule WavenetForChromeWeb.StripeWebhookController do
  use WavenetForChromeWeb, :controller
  alias WavenetForChrome.{Repo, Invoice, User}

  def create(conn, _) do
    payload = conn.assigns[:raw_body]
    [signature] = get_req_header(conn, "stripe-signature")
    secret = System.get_env("STRIPE_SIGNING_SECRET")

    case Stripe.Webhook.construct_event(payload, signature, secret) do
      {:ok, event} -> proccess_event(event, conn)
      {:error, _} -> unprocessable_entity(conn)
    end
  end

  defp proccess_event(%{type: "invoice.payment_succeeded"} = event, conn) do
    stripe_invoice = event.data.object
    customer_id = stripe_invoice.customer

    Repo.transaction(fn ->
      user = Repo.get_by!(User, stripe_customer_id: customer_id)
      Invoice.create!(user, stripe_invoice)
      User.adjust_credits!(user, stripe_invoice.amount_paid * 10_000)
    end)

    ok(conn)
  end

  defp proccess_event(%{type: event_type}, conn) do
    Sentry.capture_message("Unexpected Stripe event type '#{event_type}'.")
    ok(conn)
  end
end
