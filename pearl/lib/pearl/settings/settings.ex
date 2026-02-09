defmodule Pearl.Settings do
  @moduledoc """
  Context for managing application settings.

  Settings are stored in the database and cached in ETS for fast reads.
  The lookup chain: ETS cache (from DB) → hardcoded default.

  ## Available Settings Keys

  | Key | Default | Description |
  |-----|---------|-------------|
  | `chat_provider` | `"openrouter"` | LLM provider for chat (`"openrouter"` or `"ollama"`) |
  | `chat_model` | `"openai/gpt-5.2"` | Model identifier for chat completions |
  | `embedding_provider` | `"openrouter"` | Provider for embeddings (`"openrouter"` or `"ollama"`) |
  | `embedding_model` | `"openai/text-embedding-3-small"` | Model for generating embeddings |
  | `openrouter_api_key_env` | `"OPENROUTER_API_KEY"` | Environment variable name for OpenRouter API key |
  | `ollama_host_env` | `"OLLAMA_HOST"` | Environment variable name for Ollama host URL |
  | `embedding_batch_size` | `"100"` | Number of chunks to embed per batch |
  | `file_read_concurrency` | `"10"` | Concurrent file reads during indexing |
  | `wiki_page_timeout` | `"300000"` | Timeout in ms for wiki page generation |
  | `repos_path` | `"~/.pearl/repos"` | Directory path for cloned repositories |
  """

  import Ecto.Query
  alias Pearl.Repo
  alias Pearl.Settings.Setting

  @table :pearl_settings

  @defaults %{
    "chat_provider" => "openrouter",
    "chat_model" => "openai/gpt-5.2",
    "embedding_provider" => "openrouter",
    "embedding_model" => "openai/text-embedding-3-small",
    "openrouter_api_key_env" => "OPENROUTER_API_KEY",
    "ollama_host_env" => "OLLAMA_HOST",
    "embedding_batch_size" => "100",
    "file_read_concurrency" => "10",
    "wiki_page_timeout" => "300000",
    "repos_path" => "~/.pearl/repos"
  }

  @doc "Returns the defaults map."
  @spec defaults() :: %{String.t() => String.t()}
  def defaults, do: @defaults

  @doc "Initialize ETS table and load settings from DB."
  @spec init() :: :ok
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table])
    else
      :ets.delete_all_objects(@table)
    end

    load_from_db()
  end

  @doc "Get a setting value. Checks ETS cache, then falls back to default."
  @spec get(String.t()) :: String.t() | nil
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> Map.get(@defaults, key)
    end
  end

  @doc "Set a setting value. Writes to DB and updates ETS cache."
  @spec put(String.t(), String.t()) :: :ok | {:error, Ecto.Changeset.t() | :unknown_key}
  def put(key, value) do
    if not Map.has_key?(@defaults, key) do
      {:error, :unknown_key}
    else
      result =
        %Setting{}
        |> Setting.changeset(%{key: key, value: value})
        |> Repo.insert(
          on_conflict: [set: [value: value, updated_at: DateTime.utc_now()]],
          conflict_target: :key
        )

      case result do
        {:ok, _setting} ->
          :ets.insert(@table, {key, value})
          :ok

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "Returns all settings merged with defaults (defaults first, DB overrides)."
  @spec all() :: %{String.t() => String.t()}
  def all do
    db_settings = :ets.tab2list(@table) |> Map.new()
    Map.merge(@defaults, db_settings)
  end

  defp load_from_db do
    Setting
    |> select([s], {s.key, s.value})
    |> Repo.all()
    |> Enum.each(fn {key, value} ->
      :ets.insert(@table, {key, value})
    end)

    :ok
  end
end
