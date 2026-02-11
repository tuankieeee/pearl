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
end
