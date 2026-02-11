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

    test "returns default claude_code_model" do
      assert Settings.get("claude_code_model") == "claude-haiku-4-5-20251001"
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

    test "includes claude_code_model default" do
      assert Settings.defaults()["claude_code_model"] == "claude-haiku-4-5-20251001"
    end
  end

  describe "GenServer restart" do
    test "settings survive GenServer restart" do
      # Store a custom value
      Settings.put("chat_model", "test-model-for-restart")
      assert Settings.get("chat_model") == "test-model-for-restart"

      # Get old pid and monitor it
      old_pid = Process.whereis(Settings)
      ref = Process.monitor(old_pid)

      # Stop the GenServer
      GenServer.stop(Settings)

      # Wait for the old process to terminate
      assert_receive {:DOWN, ^ref, :process, ^old_pid, _reason}, 500

      # Wait for supervisor to restart it using event-driven approach
      wait_for_restart(Settings, old_pid)

      # Settings should still be available after restart
      assert Settings.get("chat_model") == "test-model-for-restart"
    end
  end

  defp wait_for_restart(name, old_pid, timeout \\ 500) do
    # After :DOWN is received, supervisor restarts synchronously.
    # Use :sys.get_state to block until the new GenServer is ready.
    # This is event-driven: we rely on GenServer.call blocking behavior
    # rather than polling Process.whereis in a tight loop.
    deadline = System.monotonic_time(:millisecond) + timeout
    await_ready(name, old_pid, deadline)
  end

  defp await_ready(name, old_pid, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining <= 0 do
      raise "Process #{inspect(name)} did not restart within timeout"
    end

    case Process.whereis(name) do
      pid when is_pid(pid) and pid != old_pid ->
        # New process registered - block until init/1 completes
        :sys.get_state(pid, remaining)
        :ok

      _ ->
        # Not yet registered - yield to scheduler and retry
        Process.sleep(1)
        await_ready(name, old_pid, deadline)
    end
  end
end
