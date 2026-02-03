defmodule PearlWeb.WikiLiveTest do
  use PearlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Pearl.Repositories
  alias Pearl.Wiki

  setup do
    {:ok, repo} =
      Repositories.create_repo(%{
        url: "https://github.com/test/wikilive",
        provider: "github",
        owner: "test",
        name: "wikilive",
        status: "ready"
      })

    {:ok, _} =
      Wiki.save_cache(repo, %{
        structure: %{"pages" => [%{"id" => "overview", "title" => "Overview"}]},
        pages: %{"overview" => "# Overview\n\nThis is the overview."},
        model_used: "test/model"
      })

    {:ok, repo: repo}
  end

  describe "WikiLive" do
    test "renders wiki page", %{conn: conn, repo: repo} do
      {:ok, _view, html} = live(conn, "/wiki/#{repo.id}")

      assert html =~ repo.name
    end

    test "displays wiki content", %{conn: conn, repo: repo} do
      {:ok, _view, html} = live(conn, "/wiki/#{repo.id}")

      assert html =~ "Overview"
    end

    test "shows 404 for non-existent repo", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, "/wiki/999999")
      end
    end
  end
end
