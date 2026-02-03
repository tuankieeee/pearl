defmodule Pearl.Repo.Migrations.CreateWikiCaches do
  use Ecto.Migration

  def change do
    create table(:wiki_caches) do
      add :repo_id, references(:repos, on_delete: :delete_all), null: false
      add :structure, :map, default: %{}
      add :pages, :map, default: %{}
      add :model_used, :string

      timestamps()
    end

    create index(:wiki_caches, [:repo_id])
  end
end
