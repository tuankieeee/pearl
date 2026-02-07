defmodule Pearl.Rag.Embedding do
  @moduledoc """
  Ecto schema for vector embeddings used in RAG similarity search.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pearl.Repositories.RepoRecord

  @type t :: %__MODULE__{
          id: integer() | nil,
          repo_id: integer() | nil,
          repo: RepoRecord.t() | Ecto.Association.NotLoaded.t() | nil,
          file_path: String.t() | nil,
          chunk_index: integer() | nil,
          content: String.t() | nil,
          embedding: Pgvector.Ecto.Vector.t() | nil,
          token_count: integer() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "embeddings" do
    belongs_to :repo, RepoRecord
    field :file_path, :string
    field :chunk_index, :integer
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :token_count, :integer

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for an embedding record.
  """
  def changeset(embedding, attrs) do
    embedding
    |> cast(attrs, [:repo_id, :file_path, :chunk_index, :content, :embedding, :token_count])
    |> validate_required([:repo_id, :file_path, :chunk_index, :content, :embedding])
    |> foreign_key_constraint(:repo_id)
  end
end
