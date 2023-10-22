defmodule WavenetForChrome.Repo.Migrations.AddUserIdAndIpAddressToInsights do
  use Ecto.Migration

  def change do
    alter table(:insights) do
      add :user_id, references(:users, on_delete: :nothing), null: true
      add :user_ip_address, :string, null: true
    end
  end
end
