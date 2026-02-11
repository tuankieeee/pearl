defmodule Pearl.Providers.Ollama do
  @moduledoc """
  Ollama LLM provider client.

  ## Requirements

  Requires Ollama v0.4.0+ for batch embedding support via the `/api/embed` endpoint.
  Earlier versions only support single-text embedding via `/api/embeddings`.
  """

  @behaviour Pearl.Providers.Provider

  @doc """
  Returns the Ollama API base URL from configuration or defaults to localhost.
  """
  @spec base_url() :: String.t()
  def base_url do
    Pearl.Config.ollama_host()
  end

  @impl true
  def chat(model, messages, opts) do
    body = %{
      model: model,
      messages: messages,
      stream: Keyword.get(opts, :stream, false)
    }

    case Keyword.get(opts, :stream, false) do
      false -> chat_sync(body)
      true -> chat_stream(body)
    end
  end

  defp chat_sync(body) do
    case Req.post("#{base_url()}/api/chat", json: body, receive_timeout: 300_000) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {:ok, content}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chat_stream(body) do
    case start_stream(body) do
      {:ok, resp} ->
        stream =
          Stream.resource(
            fn -> resp end,
            &next_chunk/1,
            &finish_stream/1
          )

        {:ok, stream}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_stream(body) do
    case Req.post("#{base_url()}/api/chat",
           json: body,
           into: :self,
           receive_timeout: 60_000
         ) do
      {:ok, resp} -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp next_chunk(%Req.Response{} = resp) do
    receive do
      {_ref, {:data, data}} ->
        case Jason.decode(data) do
          {:ok, %{"message" => %{"content" => content}, "done" => false}} ->
            {[content], resp}

          {:ok, %{"done" => true}} ->
            {:halt, resp}

          _ ->
            {[], resp}
        end

      {_ref, :done} ->
        {:halt, resp}

      _unexpected ->
        {[], resp}
    after
      30_000 -> {:halt, resp}
    end
  end

  @doc """
  Generates embeddings for a list of texts using Ollama's batch embed endpoint.
  """
  @impl true
  def embed(texts) when is_list(texts) do
    # Use batched /api/embed endpoint (Ollama v0.4.0+)
    # This makes a single API call for all texts instead of N calls
    body = %{
      model: embedding_model(),
      input: texts
    }

    # Increased timeout (5 min) to handle large batches which may take longer
    case Req.post("#{base_url()}/api/embed",
           json: body,
           receive_timeout: 300_000
         ) do
      {:ok, %{status: 200, body: %{"embeddings" => embeddings}}} ->
        {:ok, embeddings}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all available models from the Ollama server.
  """
  @impl true
  def list_models do
    case Req.get("#{base_url()}/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the configured embedding model name or defaults to nomic-embed-text.
  """
  @impl true
  def embedding_model do
    Pearl.Config.embedding_model()
  end

  defp finish_stream(_resp), do: :ok
end
