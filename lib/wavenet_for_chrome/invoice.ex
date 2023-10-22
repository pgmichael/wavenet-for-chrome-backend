defmodule WavenetForChrome.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Jason.Encoder,
    only: [
      :stripe_invoice_id,
      :amount,
      :hosted_invoice_url,
      :inserted_at,
      :updated_at
    ]
  }
  schema "invoices" do
    belongs_to :user, WavenetForChrome.User

    field :stripe_invoice_id, :string
    field :amount, :integer
    field :hosted_invoice_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(invoice, attrs) do
    invoice
    |> cast(attrs, [:user_id, :stripe_invoice_id, :amount, :hosted_invoice_url])
    |> validate_required([:user_id, :stripe_invoice_id, :amount, :hosted_invoice_url])
    |> validate_length(:stripe_invoice_id, min: 1, max: 100)
    |> validate_length(:hosted_invoice_url, min: 1, max: 255)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> unique_constraint(:stripe_invoice_id)
  end
end
