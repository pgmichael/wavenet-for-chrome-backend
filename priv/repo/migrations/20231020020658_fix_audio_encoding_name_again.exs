defmodule WavenetForChrome.Repo.Migrations.FixAudioEncodingNameAgain do
  use Ecto.Migration

  def change do
    rename table(:insight), :audio_encoding_name, to: :audio_encoding
  end
end
