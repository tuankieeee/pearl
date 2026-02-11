defmodule Pearl.Providers do
  @moduledoc """
  Facade for LLM provider interactions.
  Routes calls to appropriate provider client.
  """

  alias Pearl.Providers.{ClaudeCode, Ollama, OpenRouter}

  @type provider :: :ollama | :openrouter | :claude_code

  @providers %{ollama: Ollama, openrouter: OpenRouter, claude_code: ClaudeCode}

  @spec chat(provider(), String.t(), [map()], keyword()) ::
          {:ok, String.t() | Enumerable.t()} | {:error, term()}
  def chat(provider, model, messages, opts \\ []) do
    with_provider(provider, & &1.chat(model, messages, opts))
  end

  @spec embed(provider(), [String.t()]) :: {:ok, [[float()]]} | {:error, term()}
  def embed(provider, texts) do
    with_provider(provider, & &1.embed(texts))
  end

  @spec list_models(provider()) :: {:ok, [map()]} | {:error, term()}
  def list_models(provider) do
    with_provider(provider, & &1.list_models())
  end

  @spec embedding_model(provider()) :: {:ok, String.t()} | {:error, term()}
  def embedding_model(provider) do
    with_provider(provider, fn mod -> {:ok, mod.embedding_model()} end)
  end

  defp with_provider(provider, fun) do
    case @providers[provider] do
      nil -> {:error, :unknown_provider}
      mod -> fun.(mod)
    end
  end
end
