defmodule Pearl.Repo do
  @moduledoc """
  The Ecto repository for Pearl.

  Wraps PostgreSQL via Postgrex with pgvector support for
  vector similarity search used by the RAG pipeline.
  """

  use Ecto.Repo,
    otp_app: :pearl,
    adapter: Ecto.Adapters.Postgres

  # Initialize Pgvector extension for Postgrex
  def init(_context, config) do
    {:ok, Keyword.put(config, :types, Pearl.PostgrexTypes)}
  end
end
