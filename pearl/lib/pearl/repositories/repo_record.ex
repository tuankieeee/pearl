defmodule Pearl.Repositories.RepoRecord do
  @moduledoc """
  Ecto schema for repository metadata and status tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pearl.Wiki.WikiCache
  alias Pearl.Rag.Embedding

  schema "repos" do
    field :url, :string
    field :provider, :string
    field :owner, :string
    field :name, :string
    field :branch, :string, default: "main"
    field :local_path, :string
    field :status, :string, default: "pending"
    field :file_count, :integer
    field :embedding_model, :string
    field :description, :string
    field :stars, :integer
    field :language, :string
    field :pushed_at, :utc_datetime

    has_many :wiki_caches, WikiCache, foreign_key: :repo_id
    has_many :embeddings, Embedding, foreign_key: :repo_id

    timestamps()
  end

  @required_fields [:url, :provider, :owner, :name]
  @optional_fields [
    :branch,
    :local_path,
    :status,
    :file_count,
    :embedding_model,
    :description,
    :stars,
    :language,
    :pushed_at
  ]

  @doc """
  Creates a changeset for a repository record.
  """
  def changeset(repo_record, attrs) do
    repo_record
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:provider, ["github", "gitlab", "bitbucket"])
    |> validate_inclusion(:status, [
      "pending",
      "cloning",
      "analyzing",
      "generating",
      "ready",
      "failed"
    ])
    |> unique_constraint([:provider, :owner, :name, :branch])
  end
end
