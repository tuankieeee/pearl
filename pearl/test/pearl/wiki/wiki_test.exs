defmodule Pearl.WikiTest do
  use Pearl.DataCase

  alias Pearl.Wiki
  alias Pearl.Wiki.WikiCache
  alias Pearl.Repositories

  describe "get_cached/1" do
    setup do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/wiki",
          provider: "github",
          owner: "test",
          name: "wiki"
        })

      {:ok, repo: repo}
    end

    test "returns nil when no cache exists", %{repo: repo} do
      assert Wiki.get_cached(repo) == nil
    end

    test "returns cache when exists", %{repo: repo} do
      {:ok, cache} =
        Wiki.save_cache(repo, %{
          structure: %{"pages" => []},
          pages: %{},
          model_used: "test/model"
        })

      assert Wiki.get_cached(repo).id == cache.id
    end
  end

  describe "save_cache/2" do
    setup do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/wikisave",
          provider: "github",
          owner: "test",
          name: "wikisave"
        })

      {:ok, repo: repo}
    end

    test "creates wiki cache", %{repo: repo} do
      wiki_data = %{
        structure: %{"pages" => [%{"id" => "overview"}]},
        pages: %{"overview" => "# Overview"},
        model_used: "ollama/llama3"
      }

      assert {:ok, %WikiCache{} = cache} = Wiki.save_cache(repo, wiki_data)
      assert cache.structure == wiki_data.structure
      assert cache.pages == wiki_data.pages
    end

    test "replaces existing cache", %{repo: repo} do
      wiki_data1 = %{structure: %{"pages" => []}, pages: %{}, model_used: "v1"}
      wiki_data2 = %{structure: %{"pages" => []}, pages: %{"new" => "page"}, model_used: "v2"}

      {:ok, _} = Wiki.save_cache(repo, wiki_data1)
      {:ok, cache2} = Wiki.save_cache(repo, wiki_data2)

      assert cache2.model_used == "v2"
      assert cache2.pages == %{"new" => "page"}
    end
  end
end
