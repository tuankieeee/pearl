defmodule Pearl.Settings.SettingTest do
  use Pearl.DataCase

  alias Pearl.Settings.Setting

  describe "changeset/2" do
    test "valid with key and value" do
      changeset = Setting.changeset(%Setting{}, %{key: "chat_provider", value: "openrouter"})
      assert changeset.valid?
    end

    test "invalid without key" do
      changeset = Setting.changeset(%Setting{}, %{value: "openrouter"})
      refute changeset.valid?
      assert %{key: ["can't be blank"]} = errors_on(changeset)
    end

    test "valid with nil value (uses default)" do
      changeset = Setting.changeset(%Setting{}, %{key: "chat_provider", value: nil})
      assert changeset.valid?
    end
  end
end
