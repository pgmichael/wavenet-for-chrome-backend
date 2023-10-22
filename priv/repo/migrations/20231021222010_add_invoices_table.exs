defmodule WavenetForChrome.Repo.Migrations.AddInvoicesTable do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :stripe_invoice_id, :string, null: false
      add :amount, :integer, null: false
      add :hosted_invoice_url, :string, null: false

      timestamps()
    end

    create unique_index(:invoices, [:stripe_invoice_id])
  end
end
