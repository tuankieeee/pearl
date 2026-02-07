defmodule Pearl.RagTest do
  use Pearl.DataCase

  alias Pearl.Rag
  alias Pearl.Rag.Embedding
  alias Pearl.Repositories
  alias Pearl.Config

  describe "config options" do
    test "embedding_batch_size returns configured value" do
      assert Config.embedding_batch_size() > 0
    end

    test "file_read_concurrency returns configured value" do
      assert Config.file_read_concurrency() > 0
    end
  end

  describe "index_repo/2 options" do
    setup do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/indexopts",
          provider: "github",
          owner: "test",
          name: "indexopts"
        })

      {:ok, repo: repo}
    end

    test "accepts batch_size and file_concurrency options", %{repo: repo} do
      # Repo has no local_path, so get_structure returns {:error, :not_cloned}
      # This proves index_repo/2 is actually called with options
      opts = [batch_size: 50, file_concurrency: 5]
      assert {:error, :not_cloned} = Rag.index_repo(repo, opts)
    end
  end

  describe "create_embedding/1" do
    setup do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/rag",
          provider: "github",
          owner: "test",
          name: "rag"
        })

      {:ok, repo: repo}
    end

    test "creates embedding record", %{repo: repo} do
      # Create a fake 1536-dim vector
      vector = Enum.map(1..1536, fn _ -> :rand.uniform() end)

      attrs = %{
        repo_id: repo.id,
        file_path: "lib/test.ex",
        chunk_index: 0,
        content: "defmodule Test do end",
        embedding: vector,
        token_count: 5
      }

      assert {:ok, %Embedding{}} = Rag.create_embedding(attrs)
    end
  end

  describe "delete_embeddings_for_repo/1" do
    setup do
      {:ok, repo} =
        Repositories.create_repo(%{
          url: "https://github.com/test/ragdelete",
          provider: "github",
          owner: "test",
          name: "ragdelete"
        })

      vector = Enum.map(1..1536, fn _ -> :rand.uniform() end)

      {:ok, _} =
        Rag.create_embedding(%{
          repo_id: repo.id,
          file_path: "lib/test.ex",
          chunk_index: 0,
          content: "test",
          embedding: vector,
          token_count: 1
        })

      {:ok, repo: repo}
    end

    test "deletes all embeddings for a repo", %{repo: repo} do
      assert {1, nil} = Rag.delete_embeddings_for_repo(repo.id)
    end
  end
end
