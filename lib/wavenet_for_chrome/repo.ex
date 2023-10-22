defmodule WavenetForChrome.Repo do
  use Ecto.Repo,
    otp_app: :wavenet_for_chrome,
    adapter: Ecto.Adapters.Postgres
end
