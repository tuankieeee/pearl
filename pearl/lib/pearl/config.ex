defmodule Pearl.Config do
  @moduledoc """
  Centralized configuration for Pearl LLM settings.

  This module provides access to LLM provider and model configuration
  via environment variables, ensuring consistent model usage across
  the application and preventing RAG mismatches that can occur when
  provider/model are selected dynamically via UI.

  Configuration is read from application environment:
  - `:llm_provider` - The LLM provider (`:ollama` or `:openrouter`)
  - `:llm_model` - The chat model identifier string
  - `:embedding_model` - The embedding model identifier string
  """

  @doc """
  Returns the configured LLM provider.

  Reads from `Application.get_env(:pearl, :llm_provider)`.

  ## Returns
  - `:ollama` or `:openrouter` (default: `:openrouter`)
  """
  @spec provider() :: :ollama | :openrouter
  def provider do
    Application.get_env(:pearl, :llm_provider, :openrouter)
  end

  @doc """
  Returns the configured chat model.

  Reads from `Application.get_env(:pearl, :llm_model)`.

  ## Returns
  - Model identifier string (default: `"openai/gpt-5.2"`)
  """
  @spec model() :: String.t()
  def model do
    Application.get_env(:pearl, :llm_model, "openai/gpt-5.2")
  end

  @doc """
  Returns the configured embedding model.

  Reads from `Application.get_env(:pearl, :embedding_model)`.

  ## Returns
  - Embedding model identifier string (default: `"openai/text-embedding-3-small"`)
  """
  @spec embedding_model() :: String.t()
  def embedding_model do
    Application.get_env(:pearl, :embedding_model, "openai/text-embedding-3-small")
  end

  @doc """
  Returns the batch size for embedding API calls.

  Larger batches reduce API call overhead but increase memory usage.
  Reads from `Application.get_env(:pearl, :embedding_batch_size)`.

  ## Returns
  - Positive integer (default: `100`)
  """
  @spec embedding_batch_size() :: pos_integer()
  def embedding_batch_size do
    Application.get_env(:pearl, :embedding_batch_size, 100)
  end

  @doc """
  Returns the concurrency level for parallel file reading.

  Higher values speed up I/O-bound file reading but increase resource usage.
  Reads from `Application.get_env(:pearl, :file_read_concurrency)`.

  ## Returns
  - Positive integer (default: `10`)
  """
  @spec file_read_concurrency() :: pos_integer()
  def file_read_concurrency do
    Application.get_env(:pearl, :file_read_concurrency, 10)
  end
end
