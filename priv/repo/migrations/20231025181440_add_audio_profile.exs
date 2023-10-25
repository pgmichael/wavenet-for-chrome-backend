defmodule WavenetForChrome.Repo.Migrations.AddAudioProfile do
  use Ecto.Migration

  def change do
    alter table(:insights) do
      add :audio_profile, {:array, :string}
    end
  end
end
