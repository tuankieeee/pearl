defmodule Pearl.Rag.Behaviour do
  @moduledoc """
  Behaviour defining the interface for RAG operations.

  Enables mocking of `Pearl.Rag` in tests via Mox.
  """

  alias Pearl.Repositories.RepoRecord

  @typedoc "Options for `index_repo/2`: `:batch_size` and `:file_concurrency`."
  @type index_opts :: [batch_size: pos_integer(), file_concurrency: pos_integer()]

  @callback index_repo(RepoRecord.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback index_repo(RepoRecord.t(), index_opts()) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @callback ask(RepoRecord.t(), String.t(), keyword()) ::
              {:ok, String.t() | Enumerable.t()} | {:error, term()}
end
