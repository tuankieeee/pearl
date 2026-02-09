defmodule Pearl.Providers.OpenRouterTest do
  use ExUnit.Case, async: false

  alias Pearl.Providers.OpenRouter

  describe "chat/3 without API key" do
    setup do
      # Point the api key env var at a non-existent variable so Config returns nil
      original_env_var = Pearl.Settings.get("openrouter_api_key_env")
      Pearl.Settings.put("openrouter_api_key_env", "PEARL_TEST_NO_KEY")

      on_exit(fn ->
        if original_env_var do
          Pearl.Settings.put("openrouter_api_key_env", original_env_var)
        else
          Pearl.Settings.put("openrouter_api_key_env", Pearl.Settings.defaults()["openrouter_api_key_env"])
        end
      end)

      :ok
    end

    test "returns error when API key not configured" do
      messages = [%{role: "user", content: "Hello"}]
      result = OpenRouter.chat("openai/gpt-4o-mini", messages, stream: false)
      assert {:error, :no_api_key} = result
    end
  end
end
