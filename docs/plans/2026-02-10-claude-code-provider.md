# Claude Code CLI Provider Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Claude Code CLI as a local LLM provider so Pearl can use Claude models for wiki generation and RAG Q&A via the `claude` CLI, with configurable model (default: Haiku).

**Architecture:** Spawn the `claude` CLI as an Erlang Port per `chat/3` call using `--output-format stream-json --verbose --permission-mode bypassPermissions --print --`. Parse JSON lines from stdout, extracting text from `assistant` messages and cost from `result` messages. Stderr captured separately for diagnostics. Embeddings not supported — users pair `claude_code` for chat with `openrouter`/`ollama` for embeddings.

**Tech Stack:** Erlang Ports, Jason for JSON lines parsing, existing Pearl.Providers behaviour, Pearl.Settings for configuration.

---

### Task 1: Add `claude_code_model` Setting

**Files:**
- Modify: `pearl/lib/pearl/settings/settings.ex:34-58`
- Test: `pearl/test/pearl/settings/settings_test.exs`

**Step 1: Write the failing test**

Add to `pearl/test/pearl/settings/settings_test.exs` inside the `describe "get/1"` block:

```elixir
test "returns default claude_code_model" do
  assert Settings.get("claude_code_model") == "claude-haiku-4-5-20251001"
end
```

And inside the `describe "defaults/0"` block:

```elixir
test "includes claude_code_model default" do
  assert Settings.defaults()["claude_code_model"] == "claude-haiku-4-5-20251001"
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/settings/settings_test.exs -v`
Expected: FAIL — default not found, returns `nil`

**Step 3: Add the setting default**

In `pearl/lib/pearl/settings/settings.ex`, add `"claude_code_model"` to the `@defaults` map (line 34) and `:claude_code_model` to the `@type setting_key` union (line 48):

```elixir
@defaults %{
  "chat_provider" => "openrouter",
  "chat_model" => "openai/gpt-5.2",
  "embedding_provider" => "openrouter",
  "embedding_model" => "openai/text-embedding-3-small",
  "openrouter_api_key_env" => "OPENROUTER_API_KEY",
  "ollama_host_env" => "OLLAMA_HOST",
  "claude_code_model" => "claude-haiku-4-5-20251001",
  "embedding_batch_size" => "100",
  "file_read_concurrency" => "10",
  "wiki_page_timeout" => "300000",
  "repos_path" => "~/.pearl/repos"
}

@type setting_key ::
        :chat_provider
        | :chat_model
        | :embedding_provider
        | :embedding_model
        | :openrouter_api_key_env
        | :ollama_host_env
        | :claude_code_model
        | :embedding_batch_size
        | :file_read_concurrency
        | :wiki_page_timeout
        | :repos_path
```

Also update the `@moduledoc` table to include the new key.

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl/settings/settings_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl/settings/settings.ex pearl/test/pearl/settings/settings_test.exs
git commit -m "feat(settings): add claude_code_model setting with Haiku default"
```

---

### Task 2: Add Config Accessors for Claude Code

**Files:**
- Modify: `pearl/lib/pearl/config.ex:21-22,48-59`
- Test: `pearl/test/pearl/config_test.exs`

**Step 1: Write the failing tests**

Add to `pearl/test/pearl/config_test.exs`:

```elixir
describe "claude_code_model/0" do
  test "returns default model" do
    assert Config.claude_code_model() == "claude-haiku-4-5-20251001"
  end

  test "returns overridden model" do
    Settings.put("claude_code_model", "claude-sonnet-4-5-20250929")
    assert Config.claude_code_model() == "claude-sonnet-4-5-20250929"
  end
end

describe "chat_provider/0 with claude_code" do
  test "returns :claude_code when configured" do
    Settings.put("chat_provider", "claude_code")
    assert Config.chat_provider() == :claude_code
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/config_test.exs -v`
Expected: FAIL — `claude_code_model/0` undefined, `parse_provider("claude_code")` falls through to `:openrouter` default

**Step 3: Add the config accessors**

In `pearl/lib/pearl/config.ex`:

1. Update the `chat_provider/0` spec (line 21):
```elixir
@spec chat_provider() :: :ollama | :openrouter | :claude_code
```

2. Add a `parse_provider` clause for `"claude_code"` (after line 49):
```elixir
defp parse_provider("claude_code"), do: :claude_code
```

3. Add the `claude_code_model/0` accessor (after the `chat_model/0` function, around line 33):
```elixir
@doc """
Returns the model identifier for the Claude Code CLI provider.

Examples: `"claude-haiku-4-5-20251001"`, `"claude-sonnet-4-5-20250929"`.
"""
@spec claude_code_model() :: String.t() | nil
def claude_code_model do
  Settings.get("claude_code_model")
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl/config_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl/config.ex pearl/test/pearl/config_test.exs
git commit -m "feat(config): add claude_code_model accessor and parse_provider clause"
```

---

### Task 3: Implement the Claude Code Provider Module

**Files:**
- Create: `pearl/lib/pearl/providers/claude_code.ex`
- Test: `pearl/test/pearl/providers/claude_code_test.exs`

This is the core task. Split into sub-steps for TDD.

**Step 1: Write tests for CLI discovery and error handling**

Create `pearl/test/pearl/providers/claude_code_test.exs`:

```elixir
defmodule Pearl.Providers.ClaudeCodeTest do
  use Pearl.DataCase, async: false

  alias Pearl.Providers.ClaudeCode

  setup do
    Pearl.Settings.__reset__()
    :ok
  end

  describe "find_cli/0" do
    test "returns path when claude CLI is found" do
      case ClaudeCode.find_cli() do
        {:ok, path} -> assert String.ends_with?(path, "claude")
        {:error, :cli_not_found} -> :ok
      end
    end
  end

  describe "embed/1" do
    test "returns not_supported error" do
      assert {:error, :not_supported} = ClaudeCode.embed(["hello"])
    end
  end

  describe "embedding_model/0" do
    test "returns empty string" do
      assert ClaudeCode.embedding_model() == ""
    end
  end

  describe "list_models/0" do
    test "returns hardcoded list of Claude models" do
      {:ok, models} = ClaudeCode.list_models()
      assert is_list(models)
      assert length(models) > 0
      ids = Enum.map(models, & &1["id"])
      assert "claude-haiku-4-5-20251001" in ids
      assert "claude-sonnet-4-5-20250929" in ids
      assert "claude-opus-4-6" in ids
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/providers/claude_code_test.exs -v`
Expected: FAIL — module not found

**Step 3: Write the provider module skeleton**

Create `pearl/lib/pearl/providers/claude_code.ex`:

```elixir
defmodule Pearl.Providers.ClaudeCode do
  @moduledoc """
  Claude Code CLI provider.

  Spawns the `claude` CLI as an Erlang Port for each chat request.
  Parses JSON lines from stdout to extract assistant responses and cost data.

  ## Requirements

  Requires the `claude` CLI to be installed and available on PATH.
  Authentication is handled by the CLI itself (no API key needed in Pearl).

  ## Limitations

  - Embeddings are not supported. Use a different provider for `embedding_provider`.
  - The CLI is spawned fresh per request (no persistent session).
  """

  @behaviour Pearl.Providers.Provider

  require Logger

  @known_models [
    %{"id" => "claude-haiku-4-5-20251001", "name" => "Claude Haiku 4.5"},
    %{"id" => "claude-sonnet-4-5-20250929", "name" => "Claude Sonnet 4.5"},
    %{"id" => "claude-opus-4-6", "name" => "Claude Opus 4.6"}
  ]

  @doc "Finds the claude CLI executable on the system."
  @spec find_cli() :: {:ok, String.t()} | {:error, :cli_not_found}
  def find_cli do
    case System.find_executable("claude") do
      nil -> {:error, :cli_not_found}
      path -> {:ok, path}
    end
  end

  @impl true
  def chat(_model, _messages, _opts) do
    {:error, :not_implemented}
  end

  @impl true
  def embed(_texts) do
    {:error, :not_supported}
  end

  @impl true
  def list_models do
    {:ok, @known_models}
  end

  @impl true
  def embedding_model do
    ""
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl/providers/claude_code_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl/providers/claude_code.ex pearl/test/pearl/providers/claude_code_test.exs
git commit -m "feat(providers): add claude_code provider skeleton with list_models and embed stubs"
```

---

### Task 4: Implement Non-Streaming `chat/3`

**Files:**
- Modify: `pearl/lib/pearl/providers/claude_code.ex`
- Modify: `pearl/test/pearl/providers/claude_code_test.exs`

**Step 1: Write the failing test**

Add to `pearl/test/pearl/providers/claude_code_test.exs`:

```elixir
describe "build_args/3" do
  test "builds correct CLI arguments for non-streaming" do
    args = ClaudeCode.build_args("claude-haiku-4-5-20251001", "Hello world", nil)

    assert "--output-format" in args
    assert "stream-json" in args
    assert "--verbose" in args
    assert "--model" in args
    assert "claude-haiku-4-5-20251001" in args
    assert "--permission-mode" in args
    assert "bypassPermissions" in args
    assert "--print" in args
    assert "--" in args
    assert "Hello world" in args
  end

  test "includes system prompt flag when system message provided" do
    args = ClaudeCode.build_args("claude-haiku-4-5-20251001", "Hello", "You are helpful")

    assert "--system-prompt" in args
    assert "You are helpful" in args
  end
end

describe "parse_json_line/1" do
  test "extracts text from assistant message" do
    line = Jason.encode!(%{
      "type" => "assistant",
      "message" => %{
        "content" => [%{"type" => "text", "text" => "Hello!"}]
      }
    })

    assert {:text, "Hello!"} = ClaudeCode.parse_json_line(line)
  end

  test "extracts concatenated text from multiple content blocks" do
    line = Jason.encode!(%{
      "type" => "assistant",
      "message" => %{
        "content" => [
          %{"type" => "text", "text" => "Hello "},
          %{"type" => "tool_use", "name" => "Read", "id" => "1", "input" => %{}},
          %{"type" => "text", "text" => "world!"}
        ]
      }
    })

    assert {:text, "Hello world!"} = ClaudeCode.parse_json_line(line)
  end

  test "returns :done for result message" do
    line = Jason.encode!(%{
      "type" => "result",
      "subtype" => "success",
      "total_cost_usd" => 0.0042
    })

    assert {:done, %{"total_cost_usd" => 0.0042}} = ClaudeCode.parse_json_line(line)
  end

  test "returns :skip for system messages" do
    line = Jason.encode!(%{"type" => "system", "subtype" => "init"})
    assert :skip = ClaudeCode.parse_json_line(line)
  end

  test "returns :skip for unparseable lines" do
    assert :skip = ClaudeCode.parse_json_line("not json")
  end

  test "skips assistant messages with no text content" do
    line = Jason.encode!(%{
      "type" => "assistant",
      "message" => %{
        "content" => [%{"type" => "tool_use", "name" => "Read", "id" => "1", "input" => %{}}]
      }
    })

    assert :skip = ClaudeCode.parse_json_line(line)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/providers/claude_code_test.exs -v`
Expected: FAIL — functions not defined

**Step 3: Implement argument building and JSON parsing**

Replace the `chat/3` stub and add helper functions in `pearl/lib/pearl/providers/claude_code.ex`:

```elixir
@doc "Builds CLI argument list for a claude invocation."
@spec build_args(String.t(), String.t(), String.t() | nil) :: [String.t()]
def build_args(model, prompt, system_prompt) do
  base = [
    "--output-format", "stream-json",
    "--verbose",
    "--model", model,
    "--permission-mode", "bypassPermissions"
  ]

  system = if system_prompt, do: ["--system-prompt", system_prompt], else: []

  base ++ system ++ ["--print", "--", prompt]
end

@doc "Parses a single JSON line from the CLI stdout."
@spec parse_json_line(String.t()) :: {:text, String.t()} | {:done, map()} | :skip
def parse_json_line(line) do
  case Jason.decode(line) do
    {:ok, %{"type" => "assistant", "message" => %{"content" => blocks}}} ->
      text =
        blocks
        |> Enum.filter(&(&1["type"] == "text"))
        |> Enum.map_join(&(&1["text"]))

      if text != "", do: {:text, text}, else: :skip

    {:ok, %{"type" => "result"} = result} ->
      {:done, Map.take(result, ["total_cost_usd", "duration_ms", "num_turns", "usage"])}

    _ ->
      :skip
  end
end

@impl true
def chat(model, messages, opts) do
  case find_cli() do
    {:error, _} = err -> err

    {:ok, cli_path} ->
      {system_prompt, prompt} = extract_messages(messages)
      args = build_args(model, prompt, system_prompt)

      case Keyword.get(opts, :stream, false) do
        false -> chat_sync(cli_path, args)
        true -> chat_stream(cli_path, args)
      end
  end
end

defp extract_messages(messages) do
  system =
    messages
    |> Enum.filter(&(&1.role == :system or &1[:role] == "system"))
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")

  system_prompt = if system == "", do: nil, else: system

  # Use the last user message as the prompt
  user_prompt =
    messages
    |> Enum.filter(&(&1.role == :user or &1[:role] == "user"))
    |> List.last()
    |> case do
      nil -> ""
      msg -> msg.content
    end

  {system_prompt, user_prompt}
end

defp chat_sync(cli_path, args) do
  port = Port.open({:spawn_executable, cli_path}, [
    :binary, :exit_status, {:args, args}, {:line, 1_048_576}
  ])

  collect_sync(port, [])
end

defp collect_sync(port, texts) do
  receive do
    {^port, {:data, {:eol, line}}} ->
      case parse_json_line(line) do
        {:text, text} -> collect_sync(port, [text | texts])
        {:done, _result} -> finish_port(port, texts)
        :skip -> collect_sync(port, texts)
      end

    {^port, {:data, {:noeol, _partial}}} ->
      # Line too long, skip partial data
      collect_sync(port, texts)

    {^port, {:exit_status, 0}} ->
      {:ok, texts |> Enum.reverse() |> Enum.join()}

    {^port, {:exit_status, code}} ->
      {:error, {:cli_error, code}}
  after
    600_000 -> Port.close(port); {:error, :timeout}
  end
end

defp finish_port(port, texts) do
  # Drain remaining messages until exit
  receive do
    {^port, {:exit_status, _}} -> {:ok, texts |> Enum.reverse() |> Enum.join()}
    {^port, _} -> finish_port(port, texts)
  after
    10_000 -> Port.close(port); {:ok, texts |> Enum.reverse() |> Enum.join()}
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl/providers/claude_code_test.exs -v`
Expected: PASS (unit tests for `build_args` and `parse_json_line` pass; `chat/3` not tested here since it requires the CLI)

**Step 5: Commit**

```bash
git add pearl/lib/pearl/providers/claude_code.ex pearl/test/pearl/providers/claude_code_test.exs
git commit -m "feat(claude_code): implement non-streaming chat with arg building and JSON parsing"
```

---

### Task 5: Implement Streaming `chat/3`

**Files:**
- Modify: `pearl/lib/pearl/providers/claude_code.ex`

**Step 1: Write the streaming implementation**

Add to `pearl/lib/pearl/providers/claude_code.ex`:

```elixir
defp chat_stream(cli_path, args) do
  port = Port.open({:spawn_executable, cli_path}, [
    :binary, :exit_status, {:args, args}, {:line, 1_048_576}
  ])

  stream =
    Stream.resource(
      fn -> port end,
      &next_stream_chunk/1,
      &close_port/1
    )

  {:ok, stream}
end

defp next_stream_chunk(port) do
  receive do
    {^port, {:data, {:eol, line}}} ->
      case parse_json_line(line) do
        {:text, text} -> {[text], port}
        {:done, _result} -> {:halt, port}
        :skip -> {[], port}
      end

    {^port, {:data, {:noeol, _partial}}} ->
      {[], port}

    {^port, {:exit_status, _}} ->
      {:halt, port}
  after
    600_000 -> {:halt, port}
  end
end

defp close_port(port) do
  # Drain and close; port may already be closed from exit_status
  try do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end
end
```

**Step 2: Run all tests to verify nothing broke**

Run: `mix test test/pearl/providers/claude_code_test.exs -v`
Expected: PASS

**Step 3: Commit**

```bash
git add pearl/lib/pearl/providers/claude_code.ex
git commit -m "feat(claude_code): implement streaming chat via Stream.resource over Port"
```

---

### Task 6: Register Provider in Router

**Files:**
- Modify: `pearl/lib/pearl/providers/providers.ex:7-11`

**Step 1: Update the providers map and type**

In `pearl/lib/pearl/providers/providers.ex`:

```elixir
alias Pearl.Providers.{ClaudeCode, Ollama, OpenRouter}

@type provider :: :ollama | :openrouter | :claude_code

@providers %{ollama: Ollama, openrouter: OpenRouter, claude_code: ClaudeCode}
```

**Step 2: Run existing tests to verify nothing broke**

Run: `mix test -v`
Expected: PASS — existing provider routing still works, new provider available

**Step 3: Commit**

```bash
git add pearl/lib/pearl/providers/providers.ex
git commit -m "feat(providers): register claude_code in provider router"
```

---

### Task 7: Add Claude Code to Settings UI

**Files:**
- Modify: `pearl/lib/pearl_web/live/settings_live.ex:89-101,673-684`
- Test: `pearl/test/pearl_web/live/settings_live_test.exs`

**Step 1: Write the failing test**

Add to `pearl/test/pearl_web/live/settings_live_test.exs` inside the `describe "SettingsLive"` block:

```elixir
test "shows Claude Code option in chat provider dropdown", %{conn: conn} do
  {:ok, _view, html} = live(conn, "/settings")
  assert html =~ "Claude Code (Local)"
  assert html =~ ~s(value="claude_code")
end

test "does not show Claude Code in embedding provider dropdown", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/settings")
  embedding_select = element(view, "select[name='settings[embedding_provider]']")
  html = render(embedding_select)
  refute html =~ "claude_code"
end

test "shows claude_code_model input", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/settings")
  assert has_element?(view, "input[name='settings[claude_code_model]']")
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl_web/live/settings_live_test.exs -v`
Expected: FAIL — option not in dropdown, input not present

**Step 3: Add Claude Code to the chat provider dropdown**

In `pearl/lib/pearl_web/live/settings_live.ex`, add the option in the chat provider `<select>` (after the Ollama option, around line 99):

```heex
<option value="claude_code" selected={@settings["chat_provider"] == "claude_code"}>
  Claude Code (Local)
</option>
```

Add the `claude_code_model` input field. Place it after the chat model input (around line 116), inside the Chat / Generation fieldset:

```heex
<div class="form-control mt-3">
  <label class="label" for="claude_code_model">
    <span class="label-text text-sm">Claude Code Model</span>
  </label>
  <input
    type="text"
    name="settings[claude_code_model]"
    id="claude_code_model"
    value={@settings["claude_code_model"]}
    placeholder="e.g. claude-haiku-4-5-20251001"
    class="input input-bordered input-sm w-full font-mono text-xs"
    phx-debounce="500"
  />
  <label class="label">
    <span class="label-text-alt text-base-content/30">
      Used when Chat Provider is set to Claude Code
    </span>
  </label>
</div>
```

Also add `claude_code_model: :string` to the `@all_settings_types` map (line 673-684):

```elixir
@all_settings_types %{
  chat_provider: :string,
  chat_model: :string,
  claude_code_model: :string,
  embedding_provider: :string,
  embedding_model: :string,
  openrouter_api_key_env: :string,
  ollama_host_env: :string,
  embedding_batch_size: :integer,
  file_read_concurrency: :integer,
  wiki_page_timeout: :integer,
  repos_path: :string
}
```

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl_web/live/settings_live_test.exs -v`
Expected: PASS

**Step 5: Commit**

```bash
git add pearl/lib/pearl_web/live/settings_live.ex pearl/test/pearl_web/live/settings_live_test.exs
git commit -m "feat(settings-ui): add Claude Code provider option and model input"
```

---

### Task 8: Wire Claude Code Model into Chat Flow

**Files:**
- Modify: `pearl/lib/pearl/config.ex`
- Modify: `pearl/lib/pearl/rag/rag.ex:184`
- Modify: `pearl/lib/pearl/wiki/generator.ex:23`

The existing flow uses `Config.chat_model()` for all providers. When the chat provider is `claude_code`, we should use `Config.claude_code_model()` instead.

**Step 1: Write the failing test**

Add to `pearl/test/pearl/config_test.exs`:

```elixir
describe "effective_chat_model/0" do
  test "returns chat_model when provider is openrouter" do
    assert Config.effective_chat_model() == "openai/gpt-5.2"
  end

  test "returns claude_code_model when provider is claude_code" do
    Settings.put("chat_provider", "claude_code")
    assert Config.effective_chat_model() == "claude-haiku-4-5-20251001"
  end

  test "returns overridden claude_code_model when provider is claude_code" do
    Settings.put("chat_provider", "claude_code")
    Settings.put("claude_code_model", "claude-opus-4-6")
    assert Config.effective_chat_model() == "claude-opus-4-6"
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/pearl/config_test.exs -v`
Expected: FAIL — `effective_chat_model/0` undefined

**Step 3: Add the effective_chat_model accessor**

In `pearl/lib/pearl/config.ex`, add after `chat_model/0`:

```elixir
@doc """
Returns the effective chat model based on the active chat provider.

When the provider is `:claude_code`, returns `claude_code_model/0`.
Otherwise returns `chat_model/0`.
"""
@spec effective_chat_model() :: String.t() | nil
def effective_chat_model do
  case chat_provider() do
    :claude_code -> claude_code_model()
    _ -> chat_model()
  end
end
```

Then update the two call sites to use `Config.effective_chat_model()`:

In `pearl/lib/pearl/rag/rag.ex:184`, change:
```elixir
Providers.chat(Config.chat_provider(), Config.effective_chat_model(), messages, opts)
```

In `pearl/lib/pearl/wiki/generator.ex:23`, the `generate/4` function takes `provider` and `model` as explicit arguments from the caller. Check where it's called.

**Step 4: Run test to verify it passes**

Run: `mix test test/pearl/config_test.exs -v`
Expected: PASS

**Step 5: Run full test suite**

Run: `mix test -v`
Expected: PASS — no regressions

**Step 6: Commit**

```bash
git add pearl/lib/pearl/config.ex pearl/lib/pearl/rag/rag.ex
git commit -m "feat(config): add effective_chat_model that routes to provider-specific model"
```

---

### Task 9: Run Full Test Suite and Format

**Files:**
- All modified files

**Step 1: Format all code**

Run: `mix format`

**Step 2: Compile with warnings as errors**

Run: `mix compile --warnings-as-errors`
Expected: 0 warnings

**Step 3: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 4: Commit any formatting fixes**

```bash
git add -A
git commit -m "chore: format code"
```

---

### Task 10: Manual Integration Test

**Not automated.** Verify the full flow works with a real Claude CLI:

1. Start the dev server: `mix phx.server`
2. Go to Settings (`/settings`)
3. Set Chat Provider to "Claude Code (Local)"
4. Verify Claude Code Model shows "claude-haiku-4-5-20251001"
5. Save settings
6. Go to a wiki page, use the Ask panel to ask a question
7. Verify a response streams back from the Claude CLI
8. Check server logs for any errors or unexpected messages

---

## Summary

| Task | What | Key Files |
|------|------|-----------|
| 1 | Add `claude_code_model` setting | settings.ex |
| 2 | Add Config accessors | config.ex |
| 3 | Provider skeleton (embed, list_models) | claude_code.ex |
| 4 | Non-streaming chat (Port + JSON parsing) | claude_code.ex |
| 5 | Streaming chat (Stream.resource) | claude_code.ex |
| 6 | Register in router | providers.ex |
| 7 | Settings UI (dropdown + model input) | settings_live.ex |
| 8 | Wire effective_chat_model into flows | config.ex, rag.ex |
| 9 | Format + compile + test | all |
| 10 | Manual integration test | — |
