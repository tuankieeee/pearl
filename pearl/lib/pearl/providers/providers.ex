defmodule Pearl.Providers do
  @moduledoc """
  Facade for LLM provider interactions.
  Routes calls to appropriate provider client.
  """

  alias Pearl.Providers.{Ollama, OpenRouter}

  @type provider :: :ollama | :openrouter

  @providers %{ollama: Ollama, openrouter: OpenRouter}

  @spec chat(provider(), String.t(), [map()], keyword()) ::
          {:ok, String.t() | Enumerable.t()} | {:error, term()}
  def chat(provider, model, messages, opts \\ []) do
    case @providers[provider] do
      nil -> {:error, :unknown_provider}
      mod -> mod.chat(model, messages, opts)
    end
  end

  @spec embed(provider(), [String.t()]) :: {:ok, [[float()]]} | {:error, term()}
  def embed(provider, texts) do
    case @providers[provider] do
      nil -> {:error, :unknown_provider}
      mod -> mod.embed(texts)
    end
  end

  @spec list_models(provider()) :: {:ok, [map()]} | {:error, term()}
  def list_models(provider) do
    case @providers[provider] do
      nil -> {:error, :unknown_provider}
      mod -> mod.list_models()
    end
  end

  @spec embedding_model(provider()) :: String.t()
  def embedding_model(provider) do
    case @providers[provider] do
      nil -> "unknown"
      mod -> mod.embedding_model()
    end
  end
end
