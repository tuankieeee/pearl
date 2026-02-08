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

  describe "search/1" do
    setup do
      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/acme/rocket",
          provider: "github",
          owner: "acme",
          name: "rocket"
        })

      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/acme/launcher",
          provider: "github",
          owner: "acme",
          name: "launcher"
        })

      {:ok, _} =
        Repositories.create_repo(%{
          url: "https://github.com/other/widget",
          provider: "github",
          owner: "other",
          name: "widget"
        })

      :ok
    end

    test "returns repos matching owner" do
      results = Repositories.search("acme")
      assert length(results) == 2
      assert Enum.all?(results, &(&1.owner == "acme"))
    end

    test "returns repos matching name" do
      results = Repositories.search("rocket")
      assert length(results) == 1
      assert hd(results).name == "rocket"
    end

    test "search is case-insensitive" do
      results = Repositories.search("ROCKET")
      assert length(results) == 1
    end

    test "returns empty list for no matches" do
      assert Repositories.search("nonexistent") == []
    end

    test "returns empty list for empty query" do
      assert Repositories.search("") == []
    end
  end
end
