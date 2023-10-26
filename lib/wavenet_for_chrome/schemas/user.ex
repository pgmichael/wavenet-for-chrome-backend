defmodule WavenetForChrome.User do
  alias WavenetForChrome.Repo
  alias WavenetForChrome.Invoice
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Jason.Encoder,
    only: [:email, :credits, :stripe_customer_id, :secret_key]
  }
  schema "users" do
    has_many :invoices, Invoice
    has_many :insights, WavenetForChrome.Insight

    field :email, :string
    field :secret_key, :string
    field :credits, :integer, default: 0
    field :stripe_customer_id, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :secret_key, :credits, :stripe_customer_id])
    |> validate_length(:email, min: 5, max: 100)
    |> unique_constraint(:email)
    |> unique_constraint(:secret_key)
    |> unique_constraint(:stripe_customer_id)
    |> validate_number(:credits, greater_than_or_equal_to: 0)
  end

  def adjust_credits!(user, count) do
    changeset = changeset(user, %{credits: user.credits + count})

    Repo.update!(changeset)
  end
end
