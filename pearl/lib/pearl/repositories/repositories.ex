defmodule Pearl.Repositories do
  @moduledoc """
  The Repositories context handles git repository cloning and analysis.
  """

  import Ecto.Query
  alias Pearl.Repo
  alias Pearl.Repositories.{Git, RepoRecord}

  @spec create_repo(map()) :: {:ok, RepoRecord.t()} | {:error, Ecto.Changeset.t()}
  def create_repo(attrs) do
    %RepoRecord{}
    |> RepoRecord.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_repo(integer()) :: RepoRecord.t() | nil
  def get_repo(id), do: Repo.get(RepoRecord, id)

  @spec get_repo_by_url(String.t()) :: RepoRecord.t() | nil
  def get_repo_by_url(url) do
    Repo.get_by(RepoRecord, url: url)
  end

  @spec list_repos() :: [RepoRecord.t()]
  def list_repos do
    RepoRecord
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @spec update_status(RepoRecord.t(), String.t()) :: {:ok, RepoRecord.t()} | {:error, Ecto.Changeset.t()}
  def update_status(repo, status) do
    repo
    |> RepoRecord.changeset(%{status: status})
    |> Repo.update()
  end

  @spec update_repo(RepoRecord.t(), map()) :: {:ok, RepoRecord.t()} | {:error, Ecto.Changeset.t()}
  def update_repo(repo, attrs) do
    repo
    |> RepoRecord.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_repo(RepoRecord.t()) :: {:ok, RepoRecord.t()} | {:error, term()}
  def delete_repo(%RepoRecord{} = repo) do
    case delete_repo_files(repo) do
      :ok -> Repo.delete(repo)
      {:error, reason} -> {:error, {:file_deletion_failed, reason}}
    end
  end

  defp delete_repo_files(%RepoRecord{local_path: nil}), do: :ok

  defp delete_repo_files(%RepoRecord{local_path: path}) do
    if File.exists?(path) do
      case File.rm_rf(path) do
        {:ok, _} -> :ok
        {:error, reason, _} -> {:error, reason}
      end
    else
      :ok
    end
  end

  @spec clone(String.t(), keyword()) :: {:ok, RepoRecord.t()} | {:error, term()}
  def clone(url, opts \\ []) do
    with {:ok, parsed} <- Git.parse_url(url),
         {:ok, repo} <- find_or_create_repo(url, parsed),
         {:ok, repo} <- update_status(repo, "cloning"),
         target_path <- repo_path(repo),
         :ok <- ensure_parent_dir(target_path),
         {:ok, _} <- Git.clone(url, target_path, opts),
         {:ok, files} <- Git.list_files(target_path),
         {:ok, repo} <- update_repo(repo, %{local_path: target_path, file_count: length(files), status: "ready"}) do
      {:ok, repo}
    else
      {:error, _reason} = error ->
        error
    end
  end

  defp find_or_create_repo(url, parsed) do
    case get_repo_by_url(url) do
      nil ->
        create_repo(Map.put(parsed, :url, url))

      existing ->
        {:ok, existing}
    end
  end

  defp repo_path(repo) do
    base = Application.get_env(:pearl, :storage)[:repos_path] |> Path.expand()
    Path.join([base, repo.provider, repo.owner, repo.name])
  end

  defp ensure_parent_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  @spec get_structure(RepoRecord.t()) :: {:ok, map()} | {:error, term()}
  def get_structure(%RepoRecord{local_path: nil}), do: {:error, :not_cloned}

  def get_structure(%RepoRecord{local_path: path}) do
    case Git.list_files(path) do
      {:ok, files} ->
        structure = build_tree(files)
        {:ok, structure}

      error ->
        error
    end
  end

  defp build_tree(files) do
    Enum.reduce(files, %{}, fn file, acc ->
      parts = Path.split(file)
      put_in_nested(acc, parts)
    end)
  end

  defp put_in_nested(map, [file]) do
    Map.put(map, file, :file)
  end

  defp put_in_nested(map, [dir | rest]) do
    current = Map.get(map, dir, %{})
    Map.put(map, dir, put_in_nested(current, rest))
  end

  @spec read_file(RepoRecord.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def read_file(%RepoRecord{local_path: nil}, _path), do: {:error, :not_cloned}

  def read_file(%RepoRecord{local_path: repo_path}, file_path) do
    full_path = Path.join(repo_path, file_path)

    case File.read(full_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end
end
