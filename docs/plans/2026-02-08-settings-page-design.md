# Settings Page & Configuration Cleanup

## Problem

Pearl's configuration is entirely environment-variable driven at startup. This creates three pain points:

1. **Too many env vars** — configuration is scattered and hard to remember
2. **No runtime changes** — server restart required for any config change
3. **No visibility** — can't see current configuration without checking env vars or logs

## Design

### Data Model

A `settings` table with key-value rows, all values stored as strings and cast on read.

```
settings
├── id          integer, primary key
├── key         string, unique index
├── value       string
├── inserted_at timestamp
└── updated_at  timestamp
```

**Lookup chain:** DB setting → environment variable → hardcoded default.

Settings are cached in an ETS table (populated on app start, refreshed on write) to avoid DB hits on every config read during wiki generation and RAG queries.

### Settings Keys

Chat and embedding providers are split to allow different providers per concern (e.g., Claude Code for chat, OpenRouter for embeddings).

| Key | Default | Description |
|-----|---------|-------------|
| `chat_provider` | `"openrouter"` | Chat/generation provider (openrouter, ollama) |
| `chat_model` | `"openai/gpt-5.2"` | Chat model identifier |
| `embedding_provider` | `"openrouter"` | Embedding provider (openrouter, ollama) |
| `embedding_model` | `"openai/text-embedding-3-small"` | Embedding model identifier |
| `openrouter_api_key_env` | `"OPENROUTER_API_KEY"` | Env var name holding OpenRouter API key |
| `ollama_host_env` | `"OLLAMA_HOST"` | Env var name holding Ollama host URL |
| `embedding_batch_size` | `"100"` | Chunks per embedding batch |
| `file_read_concurrency` | `"10"` | Parallel file reads |
| `wiki_page_timeout` | `"120000"` | Timeout per wiki page (ms) |
| `repos_path` | `"~/.pearl/repos"` | Repository storage path |

**Security:** API keys are never stored in the database. The settings table stores environment variable *names* (e.g., `"OPENROUTER_API_KEY"`), and the application reads the actual secret from the environment at runtime.

### Config Module Changes

`Pearl.Config` becomes the single source of truth. It changes from reading `Application.get_env` to reading from ETS (backed by DB), falling back to env vars, then to hardcoded defaults.

The provider abstraction layer routes based on concern:
- `Providers.chat()` reads `chat_provider` / `chat_model`
- `Providers.embed()` reads `embedding_provider` / `embedding_model`

This split enables future providers (e.g., Claude Code) for chat while keeping embeddings on OpenRouter.

### Settings Page UI

Route: `/settings` (replacing current stub in `SettingsLive`).

Single-column layout, `max-w-3xl`, three stacked cards with staggered fade-up animations.

#### Card 1 — LLM Providers

Two-column grid (`md:grid-cols-2`):
- **Left:** Chat/Generation — provider `<select>` + model text input (monospace)
- **Right:** Embeddings — provider `<select>` + model text input (monospace)

Below the grid, a **Provider Credentials** section:
- Env var name inputs (text fields, monospace)
- Live status badge per credential:
  - Green `badge-success` "Set" — env var exists
  - Yellow `badge-warning` "Not set" — env var missing
- Badges update on `phx-change` via `System.get_env/1` check on the server

#### Card 2 — Performance

Three number inputs in a row (`sm:grid-cols-3`):
- Embedding batch size (1–500)
- File read concurrency (1–100)
- Page timeout with "ms" suffix via daisyUI `join` (10,000–600,000)

Each input has a `label-text-alt` hint showing the valid range.

#### Card 3 — Storage

- Text input for repos path
- Below: resolved path display (`Path.expand/1`) in a subtle `bg-base-200/60` box
- "Exists" / "Not found" badge based on `File.dir?/1`

#### Footer

- "You have unsaved changes" warning (visible when `@dirty` is true)
- **Save Settings** button (disabled when not dirty)

#### Re-index Confirmation Modal

Triggered when saving with changed `embedding_provider` or `embedding_model`:
- daisyUI `<dialog>` modal with warning icon and explanation
- **Save & Re-index All** (`btn-warning`) — saves and queues re-indexing of all repos
- **Save Without Re-indexing** (`btn-ghost`) — saves without re-indexing (RAG will be degraded until manual re-index)

### Interaction Summary

| Trigger | Behavior |
|---------|----------|
| `phx-change` on credential inputs | Live env var existence check, badge update |
| `phx-debounce="500"` on repos path | Path expansion + directory existence check |
| `phx-change` on form | Dirty tracking (compare current vs initial values) |
| Save click | Shows re-index modal if embedding config changed, otherwise saves directly |

### Future Considerations

- **Claude Code provider:** Add as a new `chat_provider` option. Requires a new `anthropic_api_key_env` setting (default: `"ANTHROPIC_API_KEY"`). No embedding changes needed.
- **Per-repo embedding tracking:** Currently re-indexing is all-or-nothing. Future work could track which embedding model was used per repo for selective re-indexing.
