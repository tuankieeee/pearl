defmodule Pearl.Settings.SettingsTest do
  # async: false - tests share Settings state via reset() and put/get operations
  use Pearl.DataCase, async: false

  alias Pearl.Settings

  setup do
    Settings.__reset__()
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

    test "returns error for unknown key" do
      assert {:error, :unknown_key} = Settings.put("nonexistent_key", "value")
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
    test "returns all default values" do
      defaults = Settings.defaults()

      assert defaults["chat_provider"] == "openrouter"
      assert defaults["chat_model"] == "openai/gpt-5.2"
      assert defaults["embedding_provider"] == "openrouter"
      assert defaults["embedding_model"] == "openai/text-embedding-3-small"
      assert defaults["repos_path"] == "~/.pearl/repos"
    end
  end

  describe "GenServer restart" do
    test "settings survive GenServer restart" do
      # Store a custom value
      Settings.put("chat_model", "test-model-for-restart")
      assert Settings.get("chat_model") == "test-model-for-restart"

      # Stop the GenServer
      GenServer.stop(Settings)

      # Wait for supervisor to restart it
      wait_for_process(Settings)

      # Settings should still be available after restart
      assert Settings.get("chat_model") == "test-model-for-restart"
    end
  end

  defp wait_for_process(name, timeout \\ 500) do
    deadline = System.monotonic_time(:millisecond) + timeout

    wait_until_alive(name, deadline)
  end

  defp wait_until_alive(name, deadline) do
    case Process.whereis(name) do
      pid when is_pid(pid) ->
        # Verify GenServer is ready by making a synchronous call
        :sys.get_state(pid, 100)
        :ok

      nil ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          wait_until_alive(name, deadline)
        else
          raise "Process #{inspect(name)} did not restart within timeout"
        end
    end
  end
end
