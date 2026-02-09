defmodule Pearl.Settings.Setting do
  @moduledoc """
  Schema for application settings stored as key-value pairs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "settings" do
    field :key, :string
    field :value, :string

    timestamps()
  end

  @doc """
  Creates a changeset for a setting with the given attributes.
  """
  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
