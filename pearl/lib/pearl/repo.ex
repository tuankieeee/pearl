defmodule Pearl.Repo do
  use Ecto.Repo,
    otp_app: :pearl,
    adapter: Ecto.Adapters.Postgres

  # Initialize Pgvector extension for Postgrex
  def init(_context, config) do
    {:ok, Keyword.put(config, :types, Pearl.PostgrexTypes)}
  end
end
