defmodule Pearl.RepositoriesTest do
  use Pearl.DataCase

  alias Pearl.Repositories
  alias Pearl.Repositories.RepoRecord

  describe "create_repo/1" do
    test "creates repo record from valid URL" do
      attrs = %{
        url: "https://github.com/owner/repo",
        provider: "github",
        owner: "owner",
        name: "repo"
      }

      assert {:ok, %RepoRecord{} = repo} = Repositories.create_repo(attrs)
      assert repo.url == "https://github.com/owner/repo"
      assert repo.provider == "github"
      assert repo.status == "pending"
    end

    test "returns error for invalid provider" do
      attrs = %{
        url: "https://example.com/owner/repo",
        provider: "invalid",
        owner: "owner",
        name: "repo"
      }

      assert {:error, changeset} = Repositories.create_repo(attrs)
      assert "is invalid" in errors_on(changeset).provider
    end
  end

  describe "get_repo/1" do
    test "returns repo by id" do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/test",
          provider: "github",
          owner: "test",
          name: "test"
        })

      assert Repositories.get_repo(repo.id) == repo
    end

    test "returns nil for non-existent id" do
      assert Repositories.get_repo(-1) == nil
    end
  end

  describe "get_repo_by_url/1" do
    test "returns repo by URL" do
      url = "https://github.com/test/byurl"

      {:ok, repo} =
        Repositories.create_repo(%{
          url: url,
          provider: "github",
          owner: "test",
          name: "byurl"
        })

      assert Repositories.get_repo_by_url(url) == repo
    end
  end

  describe "update_status/2" do
    test "updates repo status" do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/status",
          provider: "github",
          owner: "test",
          name: "status"
        })

      assert {:ok, updated} = Repositories.update_status(repo, "cloning")
      assert updated.status == "cloning"
    end
  end

  describe "list_repos/0" do
    test "returns all repos" do
      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/test/list1",
          provider: "github",
          owner: "test",
          name: "list1"
        })

      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/test/list2",
          provider: "github",
          owner: "test",
          name: "list2"
        })

      repos = Repositories.list_repos()
      assert length(repos) >= 2
    end
  end
end
