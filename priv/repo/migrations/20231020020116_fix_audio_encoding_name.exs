defmodule WavenetForChrome.Repo.Migrations.FixAudioEncodingName do
  use Ecto.Migration

  def change do
    rename table(:insight), :audio_audio_encoding, to: :audio_encoding_name
  end
end
