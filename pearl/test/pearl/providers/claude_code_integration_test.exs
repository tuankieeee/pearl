defmodule Pearl.Providers.ClaudeCodeIntegrationTest do
  @moduledoc """
  Integration tests for the Claude Code provider.

  These tests exercise the full call chain from Providers facade through
  ClaudeCode's Port-based CLI interaction, JSON stream parsing, and response
  assembly. Only the actual `claude` CLI binary is replaced with fake scripts
  that produce the same JSON stream format.
  """
  use Pearl.DataCase, async: false

  alias Pearl.Providers
  alias Pearl.Providers.ClaudeCode

  @fake_cli Path.expand("../../support/fake_claude.sh", __DIR__)
  @fake_cli_stream Path.expand("../../support/fake_claude_stream.sh", __DIR__)
  @fake_cli_error Path.expand("../../support/fake_claude_error.sh", __DIR__)

  setup do
    Pearl.Settings.__reset__()
    on_exit(fn -> Application.delete_env(:pearl, :claude_cli_path) end)
    :ok
  end

  describe "ClaudeCode.chat/3 sync through Port" do
    test "spawns fake CLI, parses JSON stream, and returns assembled response" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)

      messages = [
        %{role: :system, content: "You are a helpful assistant."},
        %{role: :user, content: "Say hello"}
      ]

      assert {:ok, response} =
               ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: false)

      assert response == "Hello from fake Claude!"
    end

    test "passes system prompt through --system-prompt flag" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)

      messages = [
        %{role: :system, content: "You are a JSON generator. You output ONLY valid JSON"},
        %{role: :user, content: "Analyze this structure"}
      ]

      assert {:ok, response} =
               ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: false)

      # The fake CLI detects "JSON generator" in system prompt and returns wiki structure
      assert {:ok, parsed} = Jason.decode(response)
      assert %{"pages" => [%{"id" => "overview"}]} = parsed
    end

    test "handles messages with only user role (no system prompt)" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)

      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, response} =
               ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: false)

      assert is_binary(response)
      assert response != ""
    end

    test "returns error when CLI exits with non-zero status" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli_error)

      messages = [%{role: :user, content: "Hello"}]

      assert {:error, {:cli_error, 1}} =
               ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: false)
    end
  end

  describe "ClaudeCode.chat/3 streaming through Port" do
    test "returns stream that yields text chunks from JSON lines" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli_stream)

      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, stream} = ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: true)
      assert is_function(stream) or match?(%Stream{}, stream)

      chunks = Enum.to_list(stream)
      assert chunks == ["chunk1", "chunk2", "chunk3"]
    end

    test "stream can be partially consumed" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli_stream)

      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, stream} = ClaudeCode.chat("claude-haiku-4-5-20251001", messages, stream: true)

      first = stream |> Enum.take(1)
      assert first == ["chunk1"]
    end
  end

  describe "Providers.chat/4 routing to ClaudeCode" do
    test "routes :claude_code provider to ClaudeCode module and returns response" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)

      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, "Hello from fake Claude!"} =
               Providers.chat(:claude_code, "claude-haiku-4-5-20251001", messages, stream: false)
    end

    test "routes :claude_code streaming through Providers facade" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli_stream)

      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, stream} =
               Providers.chat(:claude_code, "claude-haiku-4-5-20251001", messages, stream: true)

      assert Enum.to_list(stream) == ["chunk1", "chunk2", "chunk3"]
    end
  end

  describe "Providers.embed/2 with :claude_code" do
    test "returns :not_supported error through the facade" do
      assert {:error, :not_supported} = Providers.embed(:claude_code, ["hello world"])
    end
  end

  describe "Providers.list_models/1 with :claude_code" do
    test "returns known Claude models through the facade" do
      assert {:ok, models} = Providers.list_models(:claude_code)
      ids = Enum.map(models, & &1["id"])
      assert "claude-haiku-4-5-20251001" in ids
      assert "claude-sonnet-4-5-20250929" in ids
      assert "claude-opus-4-6" in ids
    end
  end

  describe "Config-driven model routing through provider" do
    test "effective_chat_model selects claude_code_model when provider is claude_code" do
      Pearl.Settings.put("chat_provider", "claude_code")
      Pearl.Settings.put("claude_code_model", "claude-sonnet-4-5-20250929")
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)

      # Verify config routing
      assert Pearl.Config.chat_provider() == :claude_code
      assert Pearl.Config.effective_chat_model() == "claude-sonnet-4-5-20250929"

      # Verify the full chain works: Config → Providers → ClaudeCode → response
      messages = [%{role: :user, content: "Hello"}]

      assert {:ok, response} =
               Providers.chat(
                 Pearl.Config.chat_provider(),
                 Pearl.Config.effective_chat_model(),
                 messages,
                 stream: false
               )

      assert is_binary(response)
      assert response != ""
    end

    test "effective_chat_model falls back to chat_model for non-claude_code providers" do
      Pearl.Settings.put("chat_provider", "openrouter")
      Pearl.Settings.put("chat_model", "openai/gpt-4o-mini")
      Pearl.Settings.put("claude_code_model", "claude-sonnet-4-5-20250929")

      assert Pearl.Config.chat_provider() == :openrouter
      assert Pearl.Config.effective_chat_model() == "openai/gpt-4o-mini"
    end
  end

  describe "ClaudeCode.find_cli/0 with application env override" do
    test "uses configured path when set" do
      Application.put_env(:pearl, :claude_cli_path, @fake_cli)
      assert {:ok, @fake_cli} = ClaudeCode.find_cli()
    end

    test "falls back to System.find_executable when not configured" do
      Application.delete_env(:pearl, :claude_cli_path)

      case ClaudeCode.find_cli() do
        {:ok, path} -> assert String.ends_with?(path, "claude")
        {:error, :cli_not_found} -> :ok
      end
    end
  end
end
