defmodule WavenetForChrome.Insight do
  alias WavenetForChromeWeb.TextToSpeech
  alias WavenetForChrome.{Repo, Insight}
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Jason.Encoder,
    only: [
      :user_id,
      :user_ip_address,
      :character_count,
      :voice_name,
      :voice_language_code,
      :audio_pitch,
      :audio_speaking_rate,
      :audio_volume_gain_db,
      :audio_encoding,
      :extension_version,
      :inserted_at,
      :updated_at
    ]
  }
  schema "insights" do
    belongs_to :user, WavenetForChrome.User

    field :user_ip_address, :string
    field :character_count, :integer
    field :voice_name, :string
    field :voice_language_code, :string
    field :audio_pitch, :float
    field :audio_speaking_rate, :float
    field :audio_volume_gain_db, :float
    field :audio_encoding, :string
    field :audio_profile, {:array, :string}
    field :extension_version, :string, default: "UNKNOWN"

    timestamps(type: :utc_datetime)
  end

  def changeset(insight, attrs) do
    insight
    |> cast(attrs, [
      :user_id,
      :user_ip_address,
      :character_count,
      :voice_name,
      :voice_language_code,
      :audio_pitch,
      :audio_speaking_rate,
      :audio_volume_gain_db,
      :audio_encoding,
      :audio_profile,
      :extension_version
    ])
    |> validate_required([
      :user_ip_address,
      :character_count,
      :voice_name,
      :voice_language_code,
      :audio_pitch,
      :audio_speaking_rate,
      :audio_volume_gain_db,
      :audio_encoding
    ])
  end

  def track(params, user_ip_address \\ nil, user_id \\ nil) do
    attrs =
      Map.merge(params, %{
        "character_count" => TextToSpeech.get_character_count!(params),
        "user_id" => user_id,
        "user_ip_address" => user_ip_address
      })

    changeset = changeset(%Insight{}, attrs)

    case Repo.insert(changeset) do
      {:ok, insight} ->
        {:ok, insight}

      {:error, error} ->
        throw(error)
        Sentry.capture_message("Failed to create insight: #{inspect(error)}")
        {:error, error}
    end
  end
end
