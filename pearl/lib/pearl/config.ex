defmodule Pearl.Config do
  @moduledoc """
  Centralized configuration for Pearl.

  Reads settings from `Pearl.Settings` (ETS-cached, DB-backed).
  Provides typed accessors for all configuration values.
  """

  alias Pearl.Settings

  # --- Chat / Generation ---

  @spec chat_provider() :: :ollama | :openrouter
  def chat_provider, do: parse_provider(Settings.get("chat_provider"))

  @spec chat_model() :: String.t()
  def chat_model do
    Settings.get("chat_model")
  end

  # --- Embeddings ---

  @spec embedding_provider() :: :ollama | :openrouter
  def embedding_provider, do: parse_provider(Settings.get("embedding_provider"))

  @spec parse_provider(String.t()) :: :ollama | :openrouter
  defp parse_provider("ollama"), do: :ollama
  defp parse_provider(_), do: :openrouter

  @spec embedding_model() :: String.t()
  def embedding_model do
    Settings.get("embedding_model")
  end

  # --- Provider credentials (env var indirection) ---

  @spec openrouter_api_key_env() :: String.t()
  def openrouter_api_key_env do
    Settings.get("openrouter_api_key_env")
  end

  @spec openrouter_api_key() :: String.t() | nil
  def openrouter_api_key do
    System.get_env(openrouter_api_key_env())
  end

  @spec ollama_host() :: String.t()
  def ollama_host do
    env_var = Settings.get("ollama_host_env")
    System.get_env(env_var) || "http://localhost:11434"
  end

  # --- Performance ---

  @spec embedding_batch_size() :: pos_integer()
  def embedding_batch_size do
    Settings.get("embedding_batch_size") |> String.to_integer()
  end

  @spec file_read_concurrency() :: pos_integer()
  def file_read_concurrency do
    Settings.get("file_read_concurrency") |> String.to_integer()
  end

  @spec wiki_page_timeout() :: pos_integer()
  def wiki_page_timeout do
    Settings.get("wiki_page_timeout") |> String.to_integer()
  end

  # --- Storage ---

  @spec repos_path() :: String.t()
  def repos_path do
    Settings.get("repos_path")
  end
end
