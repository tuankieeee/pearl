defmodule Pearl.Wiki.Prompts do
  @moduledoc """
  LLM prompts for wiki generation.
  """

  @spec structure_prompt(map()) :: [map()]
  def structure_prompt(file_tree) do
    tree_json = Jason.encode!(file_tree, pretty: true)

    [
      %{
        role: "system",
        content: """
        You are a JSON generator. You output ONLY valid JSON, nothing else.
        No explanations, no markdown, no code blocks - just raw JSON.

        Your response must be a JSON object with a "pages" array:
        {"pages": [{"id": "...", "title": "...", "description": "..."}]}

        TASK: Analyze the file tree to infer what this project IS - its identity, purpose,
        domain, and capabilities. Then create a wiki structure that documents it meaningfully.

        REQUIRED PAGES (in this order):
        1. "overview" - What the project IS: its purpose, key capabilities, tech stack,
           and high-level architecture. Help readers understand the project's identity.
        2. "getting-started" - Prerequisites, installation steps, configuration,
           environment setup, and running the project for the first time.
        3. "architecture" - System components, how they interact, data flow,
           and key design decisions. Include module/package organization.

        ADDITIONAL PAGES (3-7 more based on what you discover):
        - Look for domain-specific patterns: API routes, database models, CLI commands,
          UI components, background jobs, integrations, etc.
        - Each page must cover a DISTINCT aspect - no overlapping content
        - Name pages after what they document (e.g., "api-endpoints", "data-models",
          "authentication", "deployment")
        - Skip generic pages like "Testing" or "Contributing" unless the codebase
          has substantial, unique content for them

        ANTI-PATTERNS TO AVOID:
        - Redundant pages covering the same code from different angles
        - Vague pages like "Core Features" or "Main Functionality"
        - Pages that would just repeat the Overview content
        - Splitting naturally related content across multiple pages

        Rules:
        - Use kebab-case for IDs (e.g., "getting-started", "api-endpoints")
        - Total: 6-10 pages (3 required + 3-7 domain-specific)
        - Output raw JSON only
        """
      },
      %{
        role: "user",
        content: "Create wiki structure for a project with: src/, tests/, README.md"
      },
      %{
        role: "assistant",
        content:
          ~s({"pages": [{"id": "overview", "title": "Overview", "description": "Project overview and purpose"}, {"id": "getting-started", "title": "Getting Started", "description": "Installation and setup"}, {"id": "architecture", "title": "Architecture", "description": "Code structure and design"}]})
      },
      %{
        role: "user",
        content: """
        Analyze this repository file structure and create a wiki structure:

        #{tree_json}
        """
      }
    ]
  end

  @doc "Builds an LLM prompt for generating a single wiki page from file contents."
  @spec page_prompt(map(), [{String.t(), String.t()}]) :: [map()]
  def page_prompt(page_spec, file_contents) do
    page_prompt(page_spec, file_contents, :default)
  end

  @spec page_prompt(map(), [{String.t(), String.t()}], atom()) :: [map()]
  def page_prompt(page_spec, file_contents, page_type) do
    context = format_context(file_contents)
    system_prompt = build_system_prompt(page_type)

    [
      %{
        role: "system",
        content: system_prompt
      },
      %{
        role: "user",
        content: """
        Write a wiki page for: #{page_spec.title}
        Description: #{page_spec[:description] || page_spec.title}

        Relevant code context:
        #{context}
        """
      }
    ]
  end

  defp format_context(file_contents) do
    file_contents
    |> Enum.map(fn {path, content} ->
      """
      === #{path} ===
      #{String.slice(content, 0, 5000)}
      """
    end)
    |> Enum.join("\n\n")
  end

  defp build_system_prompt(page_type) do
    base_guidelines = base_guidelines()
    anti_hallucination = anti_hallucination_rules()
    type_specific = type_specific_guidelines(page_type)

    """
    You are a technical documentation writer. Write a wiki page in Markdown format.

    #{type_specific}

    #{base_guidelines}

    #{anti_hallucination}

    Output ONLY the Markdown content, no additional formatting.
    """
  end

  defp base_guidelines do
    """
    Base Guidelines:
    - Use clear, concise language
    - Structure with headers (##, ###)
    - Reference specific files when relevant
    """
  end

  defp anti_hallucination_rules do
    """
    CRITICAL - Anti-Hallucination Rules:
    - Only include information that is verifiable from the provided code context
    - Never invent URLs, version numbers, or commands not found in the code
    - Never fabricate package names, repository URLs, or external links
    - If information would require speculation, write "See README" or "requires documentation"
    - When unsure about a specific detail, omit it rather than guess
    """
  end

  defp type_specific_guidelines(:overview) do
    """
    Page Type: OVERVIEW

    Focus Areas:
    - Project identity: What IS this project? What problem does it solve?
    - Core capabilities and features (derived from code structure)
    - Technology stack (extract from mix.exs, package.json, or similar)
    - Include a high-level architecture diagram using Mermaid (```mermaid blocks)

    DO NOT Include:
    - Installation instructions (that belongs in Getting Started)
    - Detailed setup steps
    - Prerequisites or version requirements
    """
  end

  defp type_specific_guidelines(:getting_started) do
    """
    Page Type: GETTING STARTED

    Focus Areas:
    - Prerequisites with specific versions (ONLY from code, e.g., .tool-versions, mix.exs elixir version)
    - Real installation commands (ONLY from actual package files like mix.exs, package.json)
    - Configuration steps (from actual config files in the codebase)
    - A working first-run example (based on actual code entry points)

    CRITICAL:
    - Use ONLY information from the provided code context
    - Never invent repository URLs or clone commands
    - If install commands aren't clear from context, write "See project README for installation"
    - Extract real dependency names from package files
    """
  end

  defp type_specific_guidelines(:architecture) do
    """
    Page Type: ARCHITECTURE

    Focus Areas:
    - Components and their responsibilities (derived from directory/module structure)
    - Data flow between components using Mermaid diagrams (```mermaid blocks)
    - Key design patterns used (observable from code structure)
    - File paths for each component (use actual paths from context)
    - Module dependencies and relationships

    Requirements:
    - Include at least one Mermaid diagram showing component relationships
    - Reference specific file paths for each component discussed
    - Explain the "why" behind architectural decisions when evident from code
    """
  end

  defp type_specific_guidelines(:configuration) do
    """
    Page Type: CONFIGURATION

    Focus Areas:
    - Configuration options and their purposes
    - Environment variables (from .env.example, config files)
    - Default values and valid options
    - Runtime vs compile-time configuration
    - Examples of common configuration scenarios

    Requirements:
    - Document each configuration option with its purpose
    - Include example values based on actual config files
    - Explain the impact of different configuration choices
    """
  end

  defp type_specific_guidelines(:default) do
    """
    Page Type: GENERAL

    Guidelines:
    - Include code examples where helpful (use actual code from context)
    - Use Mermaid diagrams for architecture/flow when appropriate (```mermaid blocks)
    - Focus on explaining concepts and usage
    - Provide practical examples based on the actual codebase
    """
  end
end
