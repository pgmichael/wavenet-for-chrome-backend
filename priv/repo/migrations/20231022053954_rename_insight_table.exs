defmodule WavenetForChrome.Repo.Migrations.RenameInsightTable do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE insight RENAME TO insights"
  end

  def down do
    execute "ALTER TABLE insights RENAME TO insight"
  end
end
