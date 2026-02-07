defmodule Pearl.Providers.OpenRouterTest do
  use ExUnit.Case, async: false

  alias Pearl.Providers.OpenRouter

  describe "chat/3 without API key" do
    test "returns error when API key not configured" do
      # Temporarily clear the API key to test the no-key case
      original = Application.get_env(:pearl, :providers)

      Application.put_env(
        :pearl,
        :providers,
        Keyword.put(original, :openrouter, Keyword.put(original[:openrouter], :api_key, nil))
      )

      messages = [%{role: "user", content: "Hello"}]
      result = OpenRouter.chat("openai/gpt-4o-mini", messages, stream: false)
      assert {:error, :no_api_key} = result

      # Restore original config
      Application.put_env(:pearl, :providers, original)
    end
  end
end
