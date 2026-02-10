defmodule Pearl.Rag.Behaviour do
  @moduledoc """
  Behaviour defining the interface for RAG operations.

  Enables mocking of `Pearl.Rag` in tests via Mox.
  """

  alias Pearl.Repositories.RepoRecord

  @type index_opts :: [batch_size: pos_integer(), file_concurrency: pos_integer()]

  @callback index_repo(RepoRecord.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  @callback index_repo(RepoRecord.t(), index_opts()) ::
              {:ok, non_neg_integer()} | {:error, term()}
end
