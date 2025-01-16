defmodule Furbox.Repo do
  use Ecto.Repo,
    otp_app: :furbox,
    adapter: Ecto.Adapters.SQLite3
end
