defmodule Pearl.Repositories.Git do
  @moduledoc """
  Git CLI wrapper for repository operations.
  """

  @url_patterns [
    {~r{^https?://github\.com/([^/]+)/([^/\.]+)(?:\.git)?$}, "github"},
    {~r{^https?://gitlab\.com/([^/]+)/([^/\.]+)(?:\.git)?$}, "gitlab"},
    {~r{^https?://bitbucket\.org/([^/]+)/([^/\.]+)(?:\.git)?$}, "bitbucket"}
  ]

  @doc """
  Parses a repository URL into provider, owner, and name components.

  Supports GitHub, GitLab, and Bitbucket URLs.
  """
  @spec parse_url(String.t()) :: {:ok, map()} | {:error, atom()}
  def parse_url(url) do
    case find_match(url, @url_patterns) do
      {:ok, provider, owner, name} ->
        {:ok, %{provider: provider, owner: owner, name: name}}

      :no_match ->
        if url =~ ~r{^https?://} do
          {:error, :unsupported_provider}
        else
          {:error, :invalid_url}
        end
    end
  end

  defp find_match(_url, []), do: :no_match

  defp find_match(url, [{pattern, provider} | rest]) do
    case Regex.run(pattern, url) do
      [_, owner, name] -> {:ok, provider, owner, name}
      _ -> find_match(url, rest)
    end
  end

  @doc """
  Clones a git repository to the target path.

  Performs a shallow clone (`--depth 1`). Supports optional `:branch`
  and `:token` options for authentication.
  """
  @spec clone(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def clone(url, target_path, opts \\ []) do
    branch = Keyword.get(opts, :branch, "HEAD")
    token = Keyword.get(opts, :token)

    clone_url = if token, do: inject_token(url, token), else: url

    args =
      ["clone", "--depth", "1"]
      |> maybe_add_branch(branch)
      |> Kernel.++([clone_url, target_path])

    case System.cmd("git", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, target_path}

      {output, _code} ->
        {:error, {:clone_failed, output}}
    end
  end

  defp maybe_add_branch(args, "HEAD"), do: args
  defp maybe_add_branch(args, branch), do: args ++ ["--branch", branch]

  defp inject_token(url, token) do
    uri = URI.parse(url)
    %{uri | userinfo: token} |> URI.to_string()
  end

  @doc "Lists tracked files in the repository, filtered to recognized code file extensions."
  @spec list_files(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_files(repo_path) do
    case System.cmd("git", ["ls-files"], cd: repo_path, stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.filter(&code_file?/1)

        {:ok, files}

      {output, _code} ->
        {:error, {:ls_files_failed, output}}
    end
  end

  @code_extensions ~w(.ex .exs .erl .hrl .js .jsx .ts .tsx .py .rb .go .rs .java .kt .swift .c .cpp .h .hpp .cs .php .html .css .scss .sass .less .json .yaml .yml .toml .md .mdx .txt .sh .bash .zsh)

  defp code_file?(path) do
    ext = Path.extname(path)
    ext in @code_extensions
  end
end
