defmodule Pearl.Repo.Migrations.CreateRepos do
  use Ecto.Migration

  def change do
    create table(:repos) do
      add :url, :string, null: false
      add :provider, :string, null: false
      add :owner, :string, null: false
      add :name, :string, null: false
      add :branch, :string, default: "main"
      add :local_path, :string
      add :status, :string, default: "pending"
      add :file_count, :integer

      timestamps()
    end

    create unique_index(:repos, [:provider, :owner, :name, :branch])
  end
end
