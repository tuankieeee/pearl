defmodule Pearl.Providers.OpenRouterTest do
  # async: false - modifies global Pearl.Settings state
  use Pearl.DataCase, async: false

  alias Pearl.Providers.OpenRouter

  describe "chat/3 without API key" do
    setup do
      # Point the api key env var at a non-existent variable so Config returns nil
      Pearl.Settings.put("openrouter_api_key_env", "PEARL_TEST_NO_KEY")
      on_exit(fn -> Pearl.Settings.__reset__() end)
      :ok
    end

    test "returns error when API key not configured" do
      messages = [%{role: "user", content: "Hello"}]
      result = OpenRouter.chat("openai/gpt-4o-mini", messages, stream: false)
      assert {:error, :no_api_key} = result
    end
  end
end
