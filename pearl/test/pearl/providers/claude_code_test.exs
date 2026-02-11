defmodule Pearl.Providers.ClaudeCodeTest do
  use Pearl.DataCase, async: false

  alias Pearl.Providers.ClaudeCode

  setup do
    Pearl.Settings.__reset__()
    :ok
  end

  describe "find_cli/0" do
    test "returns path when claude CLI is found" do
      case ClaudeCode.find_cli() do
        {:ok, path} -> assert String.ends_with?(path, "claude")
        {:error, :cli_not_found} -> :ok
      end
    end
  end

  describe "embed/1" do
    test "returns not_supported error" do
      assert {:error, :not_supported} = ClaudeCode.embed(["hello"])
    end
  end

  describe "embedding_model/0" do
    test "returns empty string" do
      assert ClaudeCode.embedding_model() == ""
    end
  end

  describe "list_models/0" do
    test "returns hardcoded list of Claude models" do
      {:ok, models} = ClaudeCode.list_models()
      assert is_list(models)
      assert length(models) > 0
      ids = Enum.map(models, & &1["id"])
      assert "claude-haiku-4-5-20251001" in ids
      assert "claude-sonnet-4-5-20250929" in ids
      assert "claude-opus-4-6" in ids
    end
  end

  describe "build_args/3" do
    test "builds correct CLI arguments for non-streaming" do
      args = ClaudeCode.build_args("claude-haiku-4-5-20251001", "Hello world", nil)

      assert "--output-format" in args
      assert "stream-json" in args
      assert "--verbose" in args
      assert "--model" in args
      assert "claude-haiku-4-5-20251001" in args
      assert "--permission-mode" in args
      assert "bypassPermissions" in args
      assert "--print" in args
      assert "--" in args
      assert "Hello world" in args
    end

    test "includes system prompt flag when system message provided" do
      args = ClaudeCode.build_args("claude-haiku-4-5-20251001", "Hello", "You are helpful")

      assert "--system-prompt" in args
      assert "You are helpful" in args
    end
  end

  describe "parse_json_line/1" do
    test "extracts text from assistant message" do
      line = Jason.encode!(%{
        "type" => "assistant",
        "message" => %{
          "content" => [%{"type" => "text", "text" => "Hello!"}]
        }
      })

      assert {:text, "Hello!"} = ClaudeCode.parse_json_line(line)
    end

    test "extracts concatenated text from multiple content blocks" do
      line = Jason.encode!(%{
        "type" => "assistant",
        "message" => %{
          "content" => [
            %{"type" => "text", "text" => "Hello "},
            %{"type" => "tool_use", "name" => "Read", "id" => "1", "input" => %{}},
            %{"type" => "text", "text" => "world!"}
          ]
        }
      })

      assert {:text, "Hello world!"} = ClaudeCode.parse_json_line(line)
    end

    test "returns :done for result message" do
      line = Jason.encode!(%{
        "type" => "result",
        "subtype" => "success",
        "total_cost_usd" => 0.0042
      })

      assert {:done, %{"total_cost_usd" => 0.0042}} = ClaudeCode.parse_json_line(line)
    end

    test "returns :skip for system messages" do
      line = Jason.encode!(%{"type" => "system", "subtype" => "init"})
      assert :skip = ClaudeCode.parse_json_line(line)
    end

    test "returns :skip for unparseable lines" do
      assert :skip = ClaudeCode.parse_json_line("not json")
    end

    test "skips assistant messages with no text content" do
      line = Jason.encode!(%{
        "type" => "assistant",
        "message" => %{
          "content" => [%{"type" => "tool_use", "name" => "Read", "id" => "1", "input" => %{}}]
        }
      })

      assert :skip = ClaudeCode.parse_json_line(line)
    end
  end
end
