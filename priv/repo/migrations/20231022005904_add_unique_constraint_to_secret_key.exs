defmodule WavenetForChrome.Repo.Migrations.AddUniqueConstraintToSecretKey do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:secret_key])
  end
end
