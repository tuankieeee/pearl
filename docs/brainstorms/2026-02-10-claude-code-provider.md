# Brainstorm: Claude Code CLI as LLM Provider

**Date**: 2026-02-10
**Goal**: Add Claude Code CLI as a local LLM provider for Pearl, with configurable model (default: Haiku)

## Context

Pearl has a behaviour-based provider system (`Pearl.Providers.Provider`) with 4 callbacks:
- `chat/3` - Send messages, get text or stream back
- `embed/1` - Generate embeddings for text chunks
- `list_models/0` - Return available models
- `embedding_model/0` - Return configured embedding model name

The Python Claude Agent SDK wraps the CLI via subprocess with JSON lines protocol:
- Single-shot: `claude --output-format stream-json --verbose --model MODEL --print -- "prompt"`
- Responses are JSON lines on stdout with typed messages (`assistant`, `result`, `system`)
- Text content lives in `message.content[].text` where `type == "text"`

## Key Constraint: No Embedding Support

Claude Code CLI has **no embedding endpoint**. Pearl already supports separate `chat_provider` and `embedding_provider` settings, so users would set `chat_provider=claude_code` while keeping `embedding_provider=openrouter` or `ollama`. The `embed/1` callback must still exist but can return `{:error, :not_supported}`.

---

## Approach A: Erlang Port with GenServer (Recommended)

Use `Port.open/2` with `{:spawn_executable, cli_path}` to spawn the CLI process. Wrap in a thin module that:

1. Builds the CLI command with flags
2. Opens a port, collects JSON lines from stdout
3. Parses each line, extracts text content from `assistant` messages
4. Returns accumulated text (non-streaming) or yields chunks (streaming)

```
Pearl.Providers.ClaudeCode
  ├── chat/3 → spawns `claude --print --` via Port
  │   ├── non-streaming: collects all text, returns {:ok, full_text}
  │   └── streaming: returns {:ok, Stream.resource(...)} yielding text chunks
  ├── embed/1 → {:error, :not_supported}
  ├── list_models/0 → {:ok, [hardcoded list of claude models]}
  └── embedding_model/0 → "" (unused)
```

**Process management**: Each `chat/3` call spawns a fresh CLI process (matches `--print` single-shot mode). No long-running process needed.

**Pros**:
- Clean process isolation per request
- Port gives us async message delivery naturally
- No external dependencies needed
- Matches how Pearl's existing streaming works (Stream.resource + receive)

**Cons**:
- Process startup overhead per call (~200-500ms for CLI init)
- Must handle port lifecycle carefully (cleanup on errors)

## Approach B: System.cmd (Simpler, No Streaming)

Use `System.cmd/3` for non-streaming only. Simpler but limited.

```elixir
{output, 0} = System.cmd("claude", ["--output-format", "stream-json", ...])
# Parse all JSON lines at once
```

**Pros**: Dead simple, no process management
**Cons**: Blocks the calling process, no streaming support, can't handle timeouts gracefully. Wiki generation already uses non-streaming, but RAG Q&A streaming would be lost.

## Approach C: Task-based with Ports

Spawn the port inside a `Task` to avoid blocking callers. Similar to Approach A but wraps the port in Task.async for non-streaming, keeping Stream.resource for streaming.

**Pros**: Non-blocking for non-streaming calls
**Cons**: Extra indirection, Task.async already handled by callers (wiki generator uses Task.async_stream)

---

## Recommended: Approach A

Approach A with Erlang Ports aligns best with:
- Existing streaming patterns (Ollama uses `Stream.resource` + `receive`)
- Per-request process isolation (no shared state)
- The CLI's `--print` single-shot mode

## Design Decisions

### 1. CLI Discovery

Follow the Python SDK's pattern - check multiple locations:
```elixir
defp find_cli do
  System.find_executable("claude") ||
    Path.expand("~/.npm-global/bin/claude") |> check_exists() ||
    "/usr/local/bin/claude" |> check_exists()
end
```

Or simpler: just use `System.find_executable("claude")` and error if not found.

### 2. Message Format Conversion

Pearl messages are `%{role: :system | :user | :assistant, content: String.t()}`. The CLI accepts a prompt string. Options:

**Option 1 - System prompt flag + last user message**: Use `--system-prompt` for system messages, pass the last user message as the prompt text. Ignore assistant messages (no multi-turn in single-shot mode).

**Option 2 - Concatenate into single prompt**: Build a single prompt string from the message list. Simple but loses role semantics.

**Recommended: Option 1** - It preserves the system prompt correctly and the CLI handles it natively.

### 3. Streaming Implementation

```elixir
defp chat_stream(cli_path, args) do
  port = Port.open({:spawn_executable, cli_path}, [
    :binary, :exit_status,
    {:args, args}, {:line, 1_048_576}
  ])

  stream = Stream.resource(
    fn -> {port, ""} end,
    fn {port, buffer} ->
      receive do
        {^port, {:data, {:eol, line}}} ->
          case parse_json_line(line) do
            {:text, chunk} -> {[chunk], {port, buffer}}
            :done -> {:halt, {port, buffer}}
            _other -> {[], {port, buffer}}
          end
        {^port, {:exit_status, _}} -> {:halt, {port, buffer}}
      after
        300_000 -> {:halt, {port, buffer}}
      end
    end,
    fn {port, _} -> Port.close(port) rescue _ -> :ok end
  )

  {:ok, stream}
end
```

### 4. JSON Lines Parsing

Extract text from assistant messages:
```elixir
defp parse_json_line(line) do
  case Jason.decode(line) do
    {:ok, %{"type" => "assistant", "message" => %{"content" => blocks}}} ->
      text = blocks
        |> Enum.filter(&(&1["type"] == "text"))
        |> Enum.map_join(&(&1["text"]))
      if text != "", do: {:text, text}, else: :skip

    {:ok, %{"type" => "result"}} -> :done
    _ -> :skip
  end
end
```

### 5. Model Configuration

- Setting key: `claude_code_model` (default: `"claude-haiku-4-5-20251001"`)
- CLI flag: `--model claude-haiku-4-5-20251001`
- The model list can be hardcoded since Claude models are well-known

### 6. Settings & Config Additions

```
Settings defaults:
  "claude_code_model" => "claude-haiku-4-5-20251001"

Config accessors:
  claude_code_model/0 -> String.t()

Provider routing:
  @providers map adds :claude_code => ClaudeCode

Config parse_provider/1:
  "claude_code" -> :claude_code

Settings UI:
  Add "Claude Code (Local)" option to chat_provider dropdown
  Show model input when claude_code selected
  Hide from embedding_provider (not supported)
```

### 7. Error Handling

- CLI not found: `{:error, :cli_not_found}`
- Process crash: `{:error, {:cli_error, exit_code, stderr}}`
- Parse error: `{:error, :invalid_response}`
- Timeout: `{:error, :timeout}`

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/pearl/providers/claude_code.ex` | **Create** | Provider implementation |
| `lib/pearl/providers/providers.ex` | Modify | Add `:claude_code` to `@providers` map |
| `lib/pearl/config.ex` | Modify | Add `claude_code_model/0`, update `parse_provider/1` |
| `lib/pearl/settings/settings.ex` | Modify | Add `claude_code_model` to defaults and type |
| `lib/pearl_web/live/settings_live.ex` | Modify | Add UI option for claude_code provider |
| `test/pearl/providers/claude_code_test.exs` | **Create** | Unit tests |

## Decisions

1. **Agentic tool use**: Allow it. No `--max-turns` restriction. The CLI should be able to crawl the codebase with its built-in tools (Read, Grep, Glob, etc.) to produce better answers.
2. **Permission mode**: `--permission-mode bypassPermissions` — Pearl is orchestrating, not a human, so auto-approve tool use.
3. **Stderr handling**: Separate. Keep stdout as clean JSON lines for parsing, capture stderr separately for diagnostics/error reporting.
4. **Cost tracking**: Yes, surface `total_cost_usd` from the `result` message in the UI.
