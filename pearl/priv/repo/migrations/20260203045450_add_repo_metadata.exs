defmodule Pearl.Repo.Migrations.AddRepoMetadata do
  use Ecto.Migration

  def change do
    alter table(:repos) do
      add :description, :text
      add :stars, :integer
      add :language, :string
      add :pushed_at, :utc_datetime
    end
  end
end
