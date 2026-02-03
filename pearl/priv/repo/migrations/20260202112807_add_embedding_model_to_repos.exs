defmodule Pearl.Repo.Migrations.AddEmbeddingModelToRepos do
  use Ecto.Migration

  def change do
    alter table(:repos) do
      add :embedding_model, :string
    end
  end
end
