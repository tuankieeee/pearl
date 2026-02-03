defmodule Pearl.Providers.OpenRouter do
  @moduledoc """
  OpenRouter LLM provider client.
  """

  @behaviour Pearl.Providers.Provider

  @base_url "https://openrouter.ai/api/v1"

  def base_url, do: @base_url

  @impl true
  def chat(model, messages, opts \\ []) do
    case api_key() do
      nil ->
        {:error, :no_api_key}

      key ->
        body = %{
          model: model,
          messages: messages,
          stream: Keyword.get(opts, :stream, false)
        }

        case Keyword.get(opts, :stream, false) do
          false -> chat_sync(body, key)
          true -> chat_stream(body, key)
        end
    end
  end

  defp chat_sync(body, key) do
    case Req.post("#{@base_url}/chat/completions",
           json: body,
           headers: headers(key)
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chat_stream(body, key) do
    stream =
      Stream.resource(
        fn -> start_stream(body, key) end,
        &next_chunk/1,
        &finish_stream/1
      )

    {:ok, stream}
  end

  defp start_stream(body, key) do
    {:ok, resp} =
      Req.post("#{@base_url}/chat/completions",
        json: body,
        headers: headers(key),
        into: :self,
        receive_timeout: 60_000
      )

    resp
  end

  defp next_chunk(%Req.Response{} = resp) do
    receive do
      {_ref, {:data, data}} ->
        case parse_sse_events(data) do
          :done -> {:halt, resp}
          chunks -> {chunks, resp}
        end

      {_ref, :done} ->
        {:halt, resp}
    after
      30_000 -> {:halt, resp}
    end
  end

  defp parse_sse_events(data) do
    data
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.reduce_while([], fn line, acc ->
      cond do
        line == "data: [DONE]" ->
          {:halt, :done}

        String.starts_with?(line, "data: ") ->
          json = String.trim_leading(line, "data: ")

          case Jason.decode(json) do
            {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}}
            when is_binary(content) ->
              {:cont, [content | acc]}

            _ ->
              {:cont, acc}
          end

        true ->
          {:cont, acc}
      end
    end)
    |> case do
      :done -> :done
      list when is_list(list) -> Enum.reverse(list)
    end
  end

  @impl true
  def embed(texts) do
    case api_key() do
      nil ->
        {:error, :no_api_key}

      key ->
        case Req.post("#{@base_url}/embeddings",
               json: %{
                 model: embedding_model(),
                 input: texts
               },
               headers: headers(key)
             ) do
          {:ok, %{status: 200, body: %{"data" => data}}} ->
            embeddings = Enum.map(data, & &1["embedding"])
            {:ok, embeddings}

          {:ok, %{status: 401}} ->
            {:error, :invalid_api_key}

          {:ok, %{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @impl true
  def list_models do
    case api_key() do
      nil ->
        {:error, :no_api_key}

      key ->
        case Req.get("#{@base_url}/models", headers: headers(key)) do
          {:ok, %{status: 200, body: %{"data" => models}}} ->
            chat_models =
              models
              |> Enum.filter(&(&1["type"] == "chat" or is_nil(&1["type"])))

            {:ok, chat_models}

          {:ok, %{status: status, body: body}} ->
            {:error, {:http_error, status, body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp api_key do
    Application.get_env(:pearl, :providers)[:openrouter][:api_key]
  end

  @impl true
  def embedding_model do
    Pearl.Config.embedding_model()
  end

  defp headers(key) do
    [
      {"authorization", "Bearer #{key}"},
      {"content-type", "application/json"}
    ]
  end

  defp finish_stream(_resp), do: :ok
end
