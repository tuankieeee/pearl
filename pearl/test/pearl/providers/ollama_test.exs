defmodule Pearl.Providers.OllamaTest do
  use ExUnit.Case, async: true

  alias Pearl.Providers.Ollama

  describe "base_url/0" do
    test "returns configured host or default" do
      # Default is localhost:11434
      assert Ollama.base_url() =~ "11434"
    end
  end

  describe "chat/3" do
    @tag :external
    test "returns response from Ollama" do
      messages = [%{role: "user", content: "Say hello"}]
      result = Ollama.chat("llama3.2:1b", messages, stream: false)
      assert {:ok, response} = result
      assert is_binary(response)
    end
  end

  describe "embed/1" do
    @tag :external
    test "returns embeddings for texts" do
      texts = ["Hello world"]
      result = Ollama.embed(texts)
      assert {:ok, [embedding]} = result
      assert is_list(embedding)
      assert length(embedding) > 0
    end
  end

  describe "list_models/0" do
    @tag :external
    test "returns list of available models" do
      result = Ollama.list_models()
      assert {:ok, models} = result
      assert is_list(models)
    end
  end
end
