defmodule Pearl.Repo.Migrations.CreateEmbeddings do
  use Ecto.Migration

  def change do
    create table(:embeddings) do
      add :repo_id, references(:repos, on_delete: :delete_all), null: false
      add :file_path, :string, null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536
      add :token_count, :integer

      timestamps(updated_at: false)
    end

    create index(:embeddings, [:repo_id])
    create index(:embeddings, [:repo_id, :file_path])

    # Create HNSW index for fast similarity search
    execute(
      "CREATE INDEX embeddings_embedding_idx ON embeddings USING hnsw (embedding vector_cosine_ops)",
      "DROP INDEX IF EXISTS embeddings_embedding_idx"
    )
  end
end
