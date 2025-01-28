defmodule RapierEx do
  use Rustler,
    # must match the name of the project in `mix.exs`
    otp_app: :furbox,
    # must match the name of the crate in `native/rustlerpdf/Cargo.toml`
    crate: :rapierex

  def step(_ball, _players), do: :erlang.nif_error(:nif_not_loaded)
end
