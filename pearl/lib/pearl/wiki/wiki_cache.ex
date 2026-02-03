defmodule Pearl.Wiki.WikiCache do
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

  def changeset(wiki_cache, attrs) do
    wiki_cache
    |> cast(attrs, [:repo_id, :structure, :pages, :model_used])
    |> validate_required([:repo_id])
    |> foreign_key_constraint(:repo_id)
  end
end
