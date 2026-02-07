defmodule Pearl do
  @moduledoc """
  Pearl generates comprehensive wikis from code repositories using LLM integration.

  It combines git repository analysis, RAG (Retrieval-Augmented Generation) for Q&A,
  and wiki generation via AI models. Named after Pearl I. Young, the architect of
  the NACA technical reports system.

  ## Core Contexts

    * `Pearl.Repositories` - Git repository cloning and management
    * `Pearl.Wiki` - Wiki generation pipeline and caching
    * `Pearl.Rag` - Retrieval-augmented generation for code Q&A
    * `Pearl.Providers` - LLM provider abstraction (Ollama, OpenRouter)
    * `Pearl.Config` - Centralized LLM configuration

  ## Key Data Flow

  1. **Clone & Index** - Clone a repo, chunk its files, generate vector embeddings
  2. **Generate Wiki** - Analyze structure, score files, generate pages via LLM
  3. **RAG Q&A** - Embed questions, search by similarity, stream LLM responses
  """
end
