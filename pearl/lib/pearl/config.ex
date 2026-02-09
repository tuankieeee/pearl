defmodule Pearl.Config do
  @moduledoc """
  Centralized configuration for Pearl.

  Reads settings from `Pearl.Settings` (ETS-cached, DB-backed).
  Provides typed accessors for all configuration values.
  """

  require Logger

  alias Pearl.Settings

  # --- Chat / Generation ---

  @doc """
  Returns the configured LLM provider for chat and wiki generation.

  Reads from the `"chat_provider"` setting. Defaults to `:openrouter` if
  not explicitly set to `"ollama"`.
  """
  @spec chat_provider() :: :ollama | :openrouter
  def chat_provider, do: parse_provider(Settings.get("chat_provider"))

  @doc """
  Returns the model identifier for chat and wiki generation.

  Examples: `"openai/gpt-4o-mini"`, `"llama3.2:3b"`.
  """
  @spec chat_model() :: String.t()
  def chat_model do
    Settings.get("chat_model")
  end

  # --- Embeddings ---

  @doc """
  Returns the configured LLM provider for embedding generation.

  Reads from the `"embedding_provider"` setting. Defaults to `:openrouter`
  if not explicitly set to `"ollama"`.
  """
  @spec embedding_provider() :: :ollama | :openrouter
  def embedding_provider, do: parse_provider(Settings.get("embedding_provider"))

  @spec parse_provider(String.t() | nil) :: :ollama | :openrouter
  defp parse_provider("ollama"), do: :ollama
  defp parse_provider(_), do: :openrouter

  @spec safe_integer(String.t() | nil, pos_integer()) :: pos_integer()
  defp safe_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 ->
        int

      _other ->
        Logger.debug("Failed to parse integer from #{inspect(value)}, using default #{default}")
        default
    end
  end

  defp safe_integer(_, default), do: default

  @doc """
  Returns the model identifier for embedding generation.

  Examples: `"openai/text-embedding-3-small"`, `"nomic-embed-text"`.
  """
  @spec embedding_model() :: String.t()
  def embedding_model do
    Settings.get("embedding_model")
  end

  # --- Provider credentials (env var indirection) ---

  @doc """
  Returns the environment variable name that holds the OpenRouter API key.

  By default this is `"OPENROUTER_API_KEY"`. Use `openrouter_api_key/0` to
  fetch the actual key value from the environment.
  """
  @spec openrouter_api_key_env() :: String.t()
  def openrouter_api_key_env do
    Settings.get("openrouter_api_key_env")
  end

  @doc """
  Returns the OpenRouter API key from the configured environment variable.

  Returns `nil` if the environment variable is not set.
  """
  @spec openrouter_api_key() :: String.t() | nil
  def openrouter_api_key do
    System.get_env(openrouter_api_key_env())
  end

  @doc """
  Returns the Ollama server host URL.

  Reads the environment variable name from settings, then fetches that
  variable's value. Falls back to `"http://localhost:11434"` if unset.
  """
  @spec ollama_host() :: String.t()
  def ollama_host do
    env_var = Settings.get("ollama_host_env")
    System.get_env(env_var) || "http://localhost:11434"
  end

  # --- Performance ---

  @doc """
  Returns the batch size for embedding generation.

  Controls how many text chunks are sent to the embedding provider in a
  single API call. Higher values improve throughput but use more memory.
  """
  @spec embedding_batch_size() :: pos_integer()
  def embedding_batch_size do
    Settings.get("embedding_batch_size") |> safe_integer(100)
  end

  @doc """
  Returns the concurrency limit for reading repository files.

  Controls how many files are read in parallel during repository indexing.
  """
  @spec file_read_concurrency() :: pos_integer()
  def file_read_concurrency do
    Settings.get("file_read_concurrency") |> safe_integer(10)
  end

  @doc """
  Returns the timeout in milliseconds for generating a single wiki page.

  If LLM generation exceeds this timeout, the page generation will fail.
  """
  @spec wiki_page_timeout() :: pos_integer()
  def wiki_page_timeout do
    Settings.get("wiki_page_timeout") |> safe_integer(300_000)
  end

  # --- Storage ---

  @doc """
  Returns the filesystem path where cloned repositories are stored.

  Defaults to `"~/.pearl/repos"` but can be configured via settings.
  """
  @spec repos_path() :: String.t()
  def repos_path do
    Settings.get("repos_path")
  end
end
