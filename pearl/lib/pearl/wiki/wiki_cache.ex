defmodule Pearl.Wiki.WikiCache do
  @moduledoc """
  Ecto schema for caching generated wiki content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pearl.Repositories.RepoRecord

  schema "wiki_caches" do
    belongs_to :repo, RepoRecord
    field :structure, :map, default: %{}
    field :pages, :map, default: %{}
    field :model_used, :string

    timestamps()
  end

  @doc "Builds a changeset for creating or updating a wiki cache."
  def changeset(wiki_cache, attrs) do
    wiki_cache
    |> cast(attrs, [:repo_id, :structure, :pages, :model_used])
    |> validate_required([:repo_id])
    |> foreign_key_constraint(:repo_id)
  end
end
