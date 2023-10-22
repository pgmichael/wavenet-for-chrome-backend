defmodule WavenetForChrome.Repo.Migrations.AddedUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :secret_key, :string
      add :credits, :integer, default: 0
      add :stripe_customer_id, :string
    end
  end
end
