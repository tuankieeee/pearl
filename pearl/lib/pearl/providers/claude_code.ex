defmodule Pearl.Providers.ClaudeCode do
  @moduledoc """
  Claude Code CLI provider.

  Spawns the `claude` CLI as an Erlang Port for each chat request.
  Parses JSON lines from stdout to extract assistant responses and cost data.

  ## Requirements

  Requires the `claude` CLI to be installed and available on PATH.
  Authentication is handled by the CLI itself (no API key needed in Pearl).

  ## Limitations

  - Embeddings are not supported. Use a different provider for `embedding_provider`.
  - The CLI is spawned fresh per request (no persistent session).
  """

  @behaviour Pearl.Providers.Provider

  require Logger

  @known_models [
    %{"id" => "claude-haiku-4-5-20251001", "name" => "Claude Haiku 4.5"},
    %{"id" => "claude-sonnet-4-5-20250929", "name" => "Claude Sonnet 4.5"},
    %{"id" => "claude-opus-4-6", "name" => "Claude Opus 4.6"}
  ]

  @doc "Finds the claude CLI executable on the system."
  @spec find_cli() :: {:ok, String.t()} | {:error, :cli_not_found}
  def find_cli do
    case System.find_executable("claude") do
      nil -> {:error, :cli_not_found}
      path -> {:ok, path}
    end
  end

  @impl true
  def chat(_model, _messages, _opts) do
    {:error, :not_implemented}
  end

  @impl true
  def embed(_texts) do
    {:error, :not_supported}
  end

  @impl true
  def list_models do
    {:ok, @known_models}
  end

  @impl true
  def embedding_model do
    ""
  end
end
