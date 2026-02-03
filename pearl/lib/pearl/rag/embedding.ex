defmodule Pearl.Rag.Embedding do
  use Ecto.Schema
  import Ecto.Changeset

  alias Pearl.Repositories.RepoRecord

  schema "embeddings" do
    belongs_to :repo, RepoRecord
    field :file_path, :string
    field :chunk_index, :integer
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :token_count, :integer

    timestamps(updated_at: false)
  end

  def changeset(embedding, attrs) do
    embedding
    |> cast(attrs, [:repo_id, :file_path, :chunk_index, :content, :embedding, :token_count])
    |> validate_required([:repo_id, :file_path, :chunk_index, :content, :embedding])
    |> foreign_key_constraint(:repo_id)
  end
end
