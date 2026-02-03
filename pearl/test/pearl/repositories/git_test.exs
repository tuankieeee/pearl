defmodule Pearl.Repositories.GitTest do
  use ExUnit.Case, async: true

  alias Pearl.Repositories.Git

  describe "parse_url/1" do
    test "parses GitHub HTTPS URL" do
      url = "https://github.com/owner/repo"
      assert {:ok, %{provider: "github", owner: "owner", name: "repo"}} = Git.parse_url(url)
    end

    test "parses GitHub HTTPS URL with .git suffix" do
      url = "https://github.com/owner/repo.git"
      assert {:ok, %{provider: "github", owner: "owner", name: "repo"}} = Git.parse_url(url)
    end

    test "parses GitLab URL" do
      url = "https://gitlab.com/owner/repo"
      assert {:ok, %{provider: "gitlab", owner: "owner", name: "repo"}} = Git.parse_url(url)
    end

    test "parses Bitbucket URL" do
      url = "https://bitbucket.org/owner/repo"
      assert {:ok, %{provider: "bitbucket", owner: "owner", name: "repo"}} = Git.parse_url(url)
    end

    test "returns error for invalid URL" do
      url = "not-a-url"
      assert {:error, :invalid_url} = Git.parse_url(url)
    end

    test "returns error for unsupported provider" do
      url = "https://sourcehut.org/owner/repo"
      assert {:error, :unsupported_provider} = Git.parse_url(url)
    end
  end

  describe "clone/3" do
    @tag :external
    test "clones a public repository" do
      # Uses a small test repo
      url = "https://github.com/octocat/Hello-World"
      tmp_dir = System.tmp_dir!()
      target = Path.join(tmp_dir, "test-clone-#{:rand.uniform(10000)}")

      result = Git.clone(url, target)
      assert {:ok, ^target} = result
      assert File.dir?(target)

      # Cleanup
      File.rm_rf!(target)
    end
  end
end
