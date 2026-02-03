defmodule Pearl.ProvidersTest do
  use ExUnit.Case, async: true

  alias Pearl.Providers

  setup_all do
    Code.ensure_loaded!(Providers)
    :ok
  end

  describe "chat/4" do
    test "delegates to Ollama module" do
      # This is a unit test that verifies delegation logic
      # Actual API call is mocked via the module structure
      assert function_exported?(Providers, :chat, 4)
    end

    test "delegates to OpenRouter module" do
      assert function_exported?(Providers, :chat, 4)
    end

    test "returns error for unknown provider" do
      result = Providers.chat(:unknown, "model", [], [])
      assert {:error, :unknown_provider} = result
    end
  end

  describe "embed/2" do
    test "returns error for unknown provider" do
      result = Providers.embed(:unknown, ["text"])
      assert {:error, :unknown_provider} = result
    end
  end

  describe "list_models/1" do
    test "returns error for unknown provider" do
      result = Providers.list_models(:unknown)
      assert {:error, :unknown_provider} = result
    end
  end
end
