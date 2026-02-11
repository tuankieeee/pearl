defmodule Pearl.Wiki.WikiClaudeCodeIntegrationTest do
  @moduledoc """
  Integration test for wiki generation using the Claude Code provider.

  Exercises the full pipeline: Settings → Config → Generator → Providers →
  ClaudeCode Port → JSON parsing → response assembly → cache storage.

  Only the `claude` CLI binary is replaced with a fake script that produces
  the same JSON stream format. Everything else runs for real: Config routing,
  Provider dispatch, Generator orchestration, file reading, DB caching.
  """
  use Pearl.DataCase, async: false

  alias Pearl.Wiki
  alias Pearl.Wiki.WikiCache
  alias Pearl.Repositories

  @fake_cli Path.expand("../../support/fake_claude.sh", __DIR__)

  setup do
    Pearl.Settings.__reset__()
    Application.put_env(:pearl, :claude_cli_path, @fake_cli)

    on_exit(fn ->
      Application.delete_env(:pearl, :claude_cli_path)
    end)

    # Configure Claude Code as the chat provider
    Pearl.Settings.put("chat_provider", "claude_code")
    Pearl.Settings.put("claude_code_model", "claude-haiku-4-5-20251001")

    # Create a temporary git repo with test files
    tmp_dir =
      Path.join(System.tmp_dir!(), "pearl_test_repo_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    File.write!(Path.join(tmp_dir, "README.md"), "# Test Project\n\nA test project.")
    File.mkdir_p!(Path.join(tmp_dir, "lib"))

    File.write!(
      Path.join(tmp_dir, "lib/app.ex"),
      "defmodule App do\n  def hello, do: :world\nend"
    )

    File.write!(
      Path.join(tmp_dir, "mix.exs"),
      ~s(defmodule App.MixProject do\n  use Mix.Project\nend)
    )

    {_, 0} = System.cmd("git", ["init"], cd: tmp_dir, stderr_to_stdout: true)
    {_, 0} = System.cmd("git", ["add", "."], cd: tmp_dir, stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["commit", "-m", "init", "--no-gpg-sign"],
        cd: tmp_dir,
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "Test"},
          {"GIT_AUTHOR_EMAIL", "test@test.com"},
          {"GIT_COMMITTER_NAME", "Test"},
          {"GIT_COMMITTER_EMAIL", "test@test.com"}
        ]
      )

    # Create DB record pointing to the temp repo
    {:ok, repo} =
      Repositories.create_repo(%{
        url: "https://github.com/test/wiki-integration-#{System.unique_integer([:positive])}",
        provider: "github",
        owner: "test",
        name: "wiki-int-#{System.unique_integer([:positive])}",
        local_path: tmp_dir,
        status: "ready"
      })

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, repo: repo, tmp_dir: tmp_dir}
  end

  describe "Wiki.generate/2 with Claude Code provider" do
    test "generates wiki structure and pages through full pipeline", %{repo: repo} do
      progress_messages = :ets.new(:progress, [:bag, :public])

      assert {:ok, wiki_data} =
               Wiki.generate(repo, fn msg ->
                 :ets.insert(progress_messages, {:msg, msg})
               end)

      # Verify structure was parsed from fake CLI's JSON response
      assert %{structure: structure, pages: pages, model_used: model} = wiki_data
      assert %{"pages" => [%{"id" => "overview"}]} = structure
      assert model == "claude_code/claude-haiku-4-5-20251001"

      # Verify page content was generated
      assert Map.has_key?(pages, "overview")
      assert is_binary(pages["overview"])
      assert pages["overview"] != ""

      # Verify progress callbacks were invoked
      all_messages = :ets.tab2list(progress_messages) |> Enum.map(&elem(&1, 1))
      assert Enum.any?(all_messages, &String.contains?(&1, "Analyzing"))
      assert Enum.any?(all_messages, &String.contains?(&1, "Generating"))
    end

    test "caches generated wiki in the database", %{repo: repo} do
      assert Wiki.get_cached(repo) == nil

      assert {:ok, _wiki_data} = Wiki.generate(repo)

      cached = Wiki.get_cached(repo)
      assert %WikiCache{} = cached
      assert cached.model_used == "claude_code/claude-haiku-4-5-20251001"
      assert %{"pages" => [%{"id" => "overview"}]} = cached.structure
      assert Map.has_key?(cached.pages, "overview")
    end

    test "replaces existing cache on regeneration", %{repo: repo} do
      assert {:ok, _} = Wiki.generate(repo)
      first_cache = Wiki.get_cached(repo)

      assert {:ok, _} = Wiki.generate(repo)
      second_cache = Wiki.get_cached(repo)

      assert second_cache.id != first_cache.id
      assert second_cache.model_used == "claude_code/claude-haiku-4-5-20251001"
    end

    test "uses effective_chat_model from Config", %{repo: repo} do
      Pearl.Settings.put("claude_code_model", "claude-opus-4-6")

      assert {:ok, wiki_data} = Wiki.generate(repo)

      assert wiki_data.model_used == "claude_code/claude-opus-4-6"
    end
  end

  describe "Wiki.generate/2 error handling with Claude Code" do
    test "returns error when CLI fails", %{repo: repo} do
      error_cli = Path.expand("../../support/fake_claude_error.sh", __DIR__)
      Application.put_env(:pearl, :claude_cli_path, error_cli)

      assert {:error, _reason} = Wiki.generate(repo)
    end
  end
end
