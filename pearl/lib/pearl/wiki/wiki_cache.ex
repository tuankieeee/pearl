defmodule Pearl.Wiki.WikiCache do
  @moduledoc """
  Ecto schema for caching generated wiki content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pearl.Repositories.RepoRecord

  @type t :: %__MODULE__{
          id: integer() | nil,
          repo_id: integer() | nil,
          repo: RepoRecord.t() | Ecto.Association.NotLoaded.t() | nil,
          structure: map(),
          pages: map(),
          model_used: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

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
