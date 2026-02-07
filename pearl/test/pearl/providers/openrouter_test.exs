defmodule Pearl.Providers.OpenRouterTest do
  use ExUnit.Case, async: false

  alias Pearl.Providers.OpenRouter

  describe "chat/3 without API key" do
    setup do
      original = Application.get_env(:pearl, :providers)

      on_exit(fn ->
        Application.put_env(:pearl, :providers, original)
      end)

      :ok
    end

    test "returns error when API key not configured" do
      original = Application.get_env(:pearl, :providers)

      openrouter_config = original[:openrouter] || []

      Application.put_env(
        :pearl,
        :providers,
        Keyword.put(original || [], :openrouter, Keyword.put(openrouter_config, :api_key, nil))
      )

      messages = [%{role: "user", content: "Hello"}]
      result = OpenRouter.chat("openai/gpt-4o-mini", messages, stream: false)
      assert {:error, :no_api_key} = result
    end
  end
end
