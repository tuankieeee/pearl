defmodule Pearl.Providers.Ollama do
  @moduledoc """
  Ollama LLM provider client.
  """

  @behaviour Pearl.Providers.Provider

  def base_url do
    Application.get_env(:pearl, :providers)[:ollama][:host] ||
      "http://localhost:11434"
  end

  @impl true
  def chat(model, messages, opts \\ []) do
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

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chat_stream(body) do
    stream =
      Stream.resource(
        fn -> start_stream(body) end,
        &next_chunk/1,
        &finish_stream/1
      )

    {:ok, stream}
  end

  defp start_stream(body) do
    {:ok, resp} =
      Req.post("#{base_url()}/api/chat",
        json: body,
        into: :self,
        receive_timeout: 60_000
      )

    resp
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
    after
      30_000 -> {:halt, resp}
    end
  end

  @impl true
  def embed(texts) do
    embeddings =
      Enum.map(texts, fn text ->
        case Req.post("#{base_url()}/api/embeddings",
               json: %{
                 model: embedding_model(),
                 prompt: text
               },
               receive_timeout: 120_000
             ) do
          {:ok, %{status: 200, body: %{"embedding" => embedding}}} ->
            embedding

          {:ok, %{status: status, body: body}} ->
            throw({:error, {:http_error, status, body}})

          {:error, reason} ->
            throw({:error, reason})
        end
      end)

    {:ok, embeddings}
  catch
    {:error, reason} -> {:error, reason}
  end

  @impl true
  def list_models do
    case Req.get("#{base_url()}/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        {:ok, models}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def embedding_model do
    Application.get_env(:pearl, :providers)[:ollama][:embedding_model] ||
      "nomic-embed-text"
  end

  defp finish_stream(_resp), do: :ok
end
