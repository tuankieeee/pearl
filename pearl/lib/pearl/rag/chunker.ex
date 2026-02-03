defmodule Pearl.Rag.Chunker do
  @moduledoc """
  Splits text into chunks for embedding.
  """

  @default_max_tokens 500
  @chars_per_token 4

  defstruct [:content, :index, :token_count, :file_path]

  @type t :: %__MODULE__{
          content: String.t(),
          index: non_neg_integer(),
          token_count: non_neg_integer(),
          file_path: String.t() | nil
        }

  @spec chunk_text(String.t(), keyword()) :: [t()]
  def chunk_text(text, opts \\ []) do
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    max_chars = max_tokens * @chars_per_token

    text
    |> split_into_chunks(max_chars)
    |> Enum.with_index()
    |> Enum.map(fn {content, index} ->
      %__MODULE__{
        content: content,
        index: index,
        token_count: estimate_tokens(content),
        file_path: nil
      }
    end)
  end

  @spec chunk_file(String.t(), String.t(), keyword()) :: [t()]
  def chunk_file(file_path, text, opts \\ []) do
    text
    |> chunk_text(opts)
    |> Enum.map(&%{&1 | file_path: file_path})
  end

  defp split_into_chunks(text, max_chars) do
    do_split(text, max_chars, [])
  end

  defp do_split("", _max, acc), do: Enum.reverse(acc)

  defp do_split(text, max_chars, acc) do
    text_len = String.length(text)

    if text_len <= max_chars do
      Enum.reverse([text | acc])
    else
      # Take up to max_chars and find a good break point
      chunk = String.slice(text, 0, max_chars)
      break_point = find_break_point(chunk, max_chars)

      actual_chunk = String.slice(text, 0, break_point)
      # Always advance by the full break_point to avoid infinite loops
      remaining = String.slice(text, break_point, text_len)

      do_split(remaining, max_chars, [actual_chunk | acc])
    end
  end

  defp find_break_point(chunk, max_chars) do
    len = String.length(chunk)

    # Try to find a break in the last 20% of the chunk
    search_start = max(0, trunc(len * 0.8))
    search_area = String.slice(chunk, search_start, len - search_start)

    result =
      cond do
        # Prefer breaking at double newline (paragraph)
        (idx = find_substring(search_area, "\n\n")) != nil ->
          search_start + idx + 2

        # Then single newline
        (idx = find_substring(search_area, "\n")) != nil ->
          search_start + idx + 1

        # Then last space in search area
        (idx = find_last_space(search_area)) != nil ->
          search_start + idx + 1

        # Fall back to max length
        true ->
          len
      end

    # Ensure we return at least 1 to avoid infinite loop
    max(1, min(result, max_chars))
  end

  defp find_substring(str, pattern) do
    case :binary.match(str, pattern) do
      {pos, _} -> pos
      :nomatch -> nil
    end
  end

  defp find_last_space(str) do
    reversed = String.reverse(str)
    case :binary.match(reversed, " ") do
      {pos, _} -> String.length(str) - pos - 1
      :nomatch -> nil
    end
  end

  defp estimate_tokens(text) do
    # Simple estimation: ~4 characters per token
    max(1, div(String.length(text), @chars_per_token))
  end
end
