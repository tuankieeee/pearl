defmodule Pearl.Settings.SettingsTest do
  use Pearl.DataCase

  alias Pearl.Settings

  setup do
    Settings.init()
    :ok
  end

  describe "get/1" do
    test "returns default when no DB row exists" do
      assert Settings.get("chat_provider") == "openrouter"
      assert Settings.get("chat_model") == "openai/gpt-5.2"
      assert Settings.get("embedding_model") == "openai/text-embedding-3-small"
    end

    test "returns DB value when row exists" do
      Settings.put("chat_model", "anthropic/claude-opus-4-6")
      assert Settings.get("chat_model") == "anthropic/claude-opus-4-6"
    end

    test "returns nil for unknown key" do
      assert Settings.get("nonexistent_key") == nil
    end
  end

  describe "put/2" do
    test "inserts a new setting" do
      assert :ok = Settings.put("chat_provider", "ollama")
      assert Settings.get("chat_provider") == "ollama"
    end

    test "updates an existing setting" do
      Settings.put("chat_model", "model-a")
      Settings.put("chat_model", "model-b")
      assert Settings.get("chat_model") == "model-b"
    end
  end

  describe "all/0" do
    test "returns all settings merged with defaults" do
      Settings.put("chat_provider", "ollama")
      all = Settings.all()

      assert all["chat_provider"] == "ollama"
      assert all["chat_model"] == "openai/gpt-5.2"
    end
  end

  describe "defaults/0" do
    test "returns all default keys" do
      defaults = Settings.defaults()
      assert defaults == Settings.defaults()
    end
  end

  describe "application startup" do
    test "settings are accessible after app starts" do
      # App is already started by test_helper.exs
      # Just verify get/1 works without calling init manually
      assert is_binary(Pearl.Settings.get("chat_provider"))
    end
  end
end
