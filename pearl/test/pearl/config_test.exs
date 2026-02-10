defmodule Pearl.ConfigTest do
  use Pearl.DataCase

  alias Pearl.Config
  alias Pearl.Settings

  setup do
    Settings.__reset__()
    :ok
  end

  describe "chat_provider/0" do
    test "returns default provider as atom" do
      assert Config.chat_provider() == :openrouter
    end

    test "returns overridden provider" do
      Settings.put("chat_provider", "ollama")
      assert Config.chat_provider() == :ollama
    end
  end

  describe "chat_model/0" do
    test "returns default model" do
      assert Config.chat_model() == "openai/gpt-5.2"
    end

    test "returns overridden model" do
      Settings.put("chat_model", "anthropic/claude-opus-4-6")
      assert Config.chat_model() == "anthropic/claude-opus-4-6"
    end
  end

  describe "embedding_provider/0" do
    test "returns default provider as atom" do
      assert Config.embedding_provider() == :openrouter
    end

    test "returns overridden provider" do
      Settings.put("embedding_provider", "ollama")
      assert Config.embedding_provider() == :ollama
    end
  end

  describe "embedding_model/0" do
    test "returns default model" do
      assert Config.embedding_model() == "openai/text-embedding-3-small"
    end
  end

  describe "embedding_batch_size/0" do
    test "returns integer" do
      assert Config.embedding_batch_size() == 100
    end
  end

  describe "openrouter_api_key/0" do
    test "reads from env var named in settings" do
      Settings.put("openrouter_api_key_env", "MY_CUSTOM_KEY_VAR")
      assert Config.openrouter_api_key_env() == "MY_CUSTOM_KEY_VAR"
    end
  end

  describe "ollama_host/0" do
    test "reads from env var named in settings" do
      on_exit(fn -> System.delete_env("MY_OLLAMA_HOST") end)
      System.put_env("MY_OLLAMA_HOST", "http://custom:11434")
      Settings.put("ollama_host_env", "MY_OLLAMA_HOST")
      assert Config.ollama_host() == "http://custom:11434"
    end

    test "returns default when env var not set" do
      Settings.put("ollama_host_env", "NONEXISTENT_VAR_12345")
      assert Config.ollama_host() == "http://localhost:11434"
    end
  end

  describe "repos_path/0" do
    test "returns default path" do
      assert Config.repos_path() == "~/.pearl/repos"
    end
  end
end
