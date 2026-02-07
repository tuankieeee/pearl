defmodule Pearl.Providers.Provider do
  @moduledoc """
  Behaviour defining the interface for LLM providers.
  """

  @type role :: :system | :user | :assistant
  @type message :: %{role: role(), content: String.t()}
  @type chat_opts :: [stream: boolean()]
  @type embed_result :: {:ok, [[float()]]} | {:error, term()}
  @type chat_result :: {:ok, String.t()} | {:ok, Enumerable.t()} | {:error, term()}
  @type models_result :: {:ok, [map()]} | {:error, term()}

  @callback chat(model :: String.t(), messages :: [message()], opts :: chat_opts()) ::
              chat_result()
  @callback embed(texts :: [String.t()]) :: embed_result()
  @callback list_models() :: models_result()
  @callback embedding_model() :: String.t()
end
