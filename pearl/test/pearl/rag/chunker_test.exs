defmodule Pearl.Rag.ChunkerTest do
  use ExUnit.Case, async: true

  alias Pearl.Rag.Chunker

  describe "chunk_text/2" do
    test "returns single chunk for short text" do
      text = "Hello world"
      chunks = Chunker.chunk_text(text, max_tokens: 100)
      assert length(chunks) == 1
      assert hd(chunks).content == text
    end

    test "splits long text into multiple chunks" do
      # Create text that exceeds max tokens
      text = String.duplicate("word ", 200)
      chunks = Chunker.chunk_text(text, max_tokens: 50)
      assert length(chunks) > 1
    end

    test "preserves chunk indices" do
      text = String.duplicate("word ", 200)
      chunks = Chunker.chunk_text(text, max_tokens: 50)
      indices = Enum.map(chunks, & &1.index)
      assert indices == Enum.to_list(0..(length(chunks) - 1))
    end

    test "estimates token count" do
      text = "Hello world this is a test"
      [chunk] = Chunker.chunk_text(text, max_tokens: 100)
      # Rough estimate: ~1 token per 4 chars or per word
      assert chunk.token_count > 0
      assert chunk.token_count < 20
    end
  end

  describe "chunk_file/3" do
    test "adds file_path to chunks" do
      text = "Hello world"
      chunks = Chunker.chunk_file("path/to/file.ex", text, max_tokens: 100)
      assert hd(chunks).file_path == "path/to/file.ex"
    end
  end
end
