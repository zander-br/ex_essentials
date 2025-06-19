defmodule Support.Repo do
  use Ecto.Repo,
    otp_app: :ex_essentials,
    adapter: Ecto.Adapters.Postgres
end
