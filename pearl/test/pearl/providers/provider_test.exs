defmodule Pearl.Providers.ProviderTest do
  use ExUnit.Case, async: true

  alias Pearl.Providers.Provider

  describe "behaviour callbacks" do
    test "defines required callbacks" do
      # This test verifies the behaviour module compiles
      # and documents expected callback signatures
      Code.ensure_loaded!(Provider)
      assert function_exported?(Provider, :behaviour_info, 1)
    end
  end
end
