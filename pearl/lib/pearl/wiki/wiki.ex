defmodule Pearl.Wiki do
  @moduledoc """
  The Wiki context handles wiki generation and caching.
  """

  import Ecto.Query
  alias Pearl.Config
  alias Pearl.Repo
  alias Pearl.Wiki.{Generator, WikiCache}
  alias Pearl.Repositories.RepoRecord

  @spec generate(RepoRecord.t(), (String.t() -> any())) ::
          {:ok, map()} | {:error, term()}
  def generate(repo, on_progress \\ fn _ -> :ok end) do
    provider = Config.provider()
    model = Config.model()

    case Generator.generate(repo, provider, model, on_progress) do
      {:ok, wiki_data} ->
        # Override model_used with Config-based format for consistency
        wiki_data = Map.put(wiki_data, :model_used, "#{Config.provider()}/#{Config.model()}")
        save_cache(repo, wiki_data)
        {:ok, wiki_data}

      error ->
        error
    end
  end

  @spec get_cached(RepoRecord.t()) :: WikiCache.t() | nil
  def get_cached(%RepoRecord{id: repo_id}) do
    WikiCache
    |> where([w], w.repo_id == ^repo_id)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @spec save_cache(RepoRecord.t(), map()) :: {:ok, WikiCache.t()} | {:error, Ecto.Changeset.t()}
  def save_cache(%RepoRecord{id: repo_id}, wiki_data) do
    # Delete existing cache for this repo
    WikiCache
    |> where([w], w.repo_id == ^repo_id)
    |> Repo.delete_all()

    # Insert new cache
    %WikiCache{}
    |> WikiCache.changeset(%{
      repo_id: repo_id,
      structure: wiki_data.structure,
      pages: wiki_data.pages,
      model_used: wiki_data.model_used
    })
    |> Repo.insert()
  end

  @spec delete_cache(RepoRecord.t()) :: {non_neg_integer(), nil}
  def delete_cache(%RepoRecord{id: repo_id}) do
    WikiCache
    |> where([w], w.repo_id == ^repo_id)
    |> Repo.delete_all()
  end
end
