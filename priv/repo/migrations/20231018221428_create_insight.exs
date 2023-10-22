defmodule WavenetForChrome.Repo.Migrations.CreateInsight do
  use Ecto.Migration

  def change do
    create table(:insight) do
      add :character_count, :integer

      # voice details
      add :voice_name, :string
      add :voice_language_code, :string

      # audio details
      add :audio_pitch, :float
      add :audio_speaking_rate, :float
      add :audio_volume_gain_db, :float
      add :audio_audio_encoding, :string

      # extension details
      add :extension_version, :string

      timestamps(type: :utc_datetime)
    end
  end
end
