# Docker Compose Database Setup — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Docker Compose file for Postgres + pgvector so new users can set up the database with one command, and make the DB port configurable via `PEARL_DB_PORT`.

**Architecture:** Postgres-only docker-compose at the repo root. Dev/test Elixir configs read `PEARL_DB_PORT` env var for the port. README becomes Docker-first, native install becomes a brief alternative.

**Tech Stack:** Docker Compose, PostgreSQL 18, pgvector, Elixir config

**Design doc:** `docs/plans/2026-02-07-docker-postgres-setup-design.md`

---

### Task 1: Create docker-compose.yml

**Files:**
- Create: `docker-compose.yml` (project root, next to `README.md`)

**Step 1: Create docker-compose.yml**

Write this exact content to `docker-compose.yml`:

```yaml
services:
  db:
    image: pgvector/pgvector:pg18
    ports:
      - "${PEARL_DB_PORT:-5432}:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - pearl_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pearl_pgdata:
```

**Step 2: Verify the file parses**

Run: `docker compose -f docker-compose.yml config --quiet`
Expected: No output, exit code 0 (valid compose file)

**Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add docker-compose for Postgres 18 + pgvector"
```

---

### Task 2: Add PEARL_DB_PORT to dev and test configs

**Files:**
- Modify: `pearl/config/dev.exs:4-11`
- Modify: `pearl/config/test.exs:8-14`

**Step 1: Add port to dev.exs**

In `pearl/config/dev.exs`, replace lines 4-11:

```elixir
config :pearl, Pearl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pearl_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

with:

```elixir
config :pearl, Pearl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("PEARL_DB_PORT", "5432")),
  database: "pearl_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

The only change is adding the `port:` line after `hostname:`.

**Step 2: Add port to test.exs**

In `pearl/config/test.exs`, replace lines 8-14:

```elixir
config :pearl, Pearl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pearl_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

with:

```elixir
config :pearl, Pearl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("PEARL_DB_PORT", "5432")),
  database: "pearl_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

**Step 3: Verify compilation**

Run from `pearl/` directory: `mix compile --warnings-as-errors`
Expected: Compilation succeeds with no warnings.

**Step 4: Verify tests still pass**

Run from `pearl/` directory: `mix test`
Expected: All tests pass (PEARL_DB_PORT not set, defaults to 5432, same as before).

**Step 5: Commit**

```bash
git add pearl/config/dev.exs pearl/config/test.exs
git commit -m "feat: make DB port configurable via PEARL_DB_PORT env var"
```

---

### Task 3: Update README with Docker-first setup

**Files:**
- Modify: `README.md`

**Step 1: Replace the PostgreSQL prerequisites section**

In `README.md`, replace the "### 2. PostgreSQL with pgvector" section (lines 42-55):

```markdown
### 2. PostgreSQL with pgvector

Pearl uses PostgreSQL to store repository data and vector embeddings for search.

#### macOS (using Homebrew)

\```bash
brew install postgresql@16 pgvector
brew services start postgresql@16
\```

#### Other platforms

See the [PostgreSQL download page](https://www.postgresql.org/download/) and [pgvector installation instructions](https://github.com/pgvector/pgvector#installation).
```

with:

```markdown
### 2. PostgreSQL with pgvector

Pearl uses PostgreSQL to store repository data and vector embeddings for search. The easiest way is Docker (recommended):

\```bash
docker compose up -d
\```

This starts PostgreSQL 18 with pgvector pre-installed. Data persists across restarts via a named volume.

**Port conflict?** If port 5432 is already in use:

\```bash
export PEARL_DB_PORT=5433
docker compose up -d
\```

<details>
<summary>Alternative: Native install</summary>

#### macOS (using Homebrew)

\```bash
brew install postgresql@16 pgvector
brew services start postgresql@16
\```

#### Other platforms

See the [PostgreSQL download page](https://www.postgresql.org/download/) and [pgvector installation instructions](https://github.com/pgvector/pgvector#installation).

</details>
```

**Step 2: Simplify the Setup section**

Replace the Setup section (lines 80-122) with:

```markdown
## Setup

1. **Clone this repository:**

   \```bash
   git clone https://github.com/existential-birds/pearl.git
   cd pearl/pearl
   \```

2. **Start PostgreSQL** (if using Docker):

   \```bash
   docker compose up -d
   \```

3. **Configure your LLM provider** by setting environment variables (either export directly in your terminal or add to a `.env` file to source later):

   \```bash
   # For OpenRouter (recommended)
   export LLM_PROVIDER=openrouter
   export LLM_MODEL=openai/gpt-5.2
   export EMBEDDING_MODEL=openai/text-embedding-3-small
   export OPENROUTER_API_KEY=sk-your-key-here

   # For Ollama (local)
   # export LLM_PROVIDER=ollama
   # export OLLAMA_HOST=http://localhost:11434
   # export OLLAMA_DEFAULT_MODEL=llama3.2:3b
   \```

4. **Run setup:**

   \```bash
   mix setup
   \```

5. **Start the server:**

   \```bash
   mix phx.server
   \```

6. **Open Pearl** in your browser at [http://localhost:4000](http://localhost:4000)
```

Note: The `cd assets && npm install` step is removed because `mix setup` already handles asset installation.

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: Docker-first setup instructions in README"
```

---

### Task 4: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add docker compose to Development Commands**

In `CLAUDE.md`, in the Development Commands code block (lines 13-41), add `docker compose up -d` before `mix setup`:

```bash
# Start PostgreSQL (Docker)
docker compose up -d

# Setup (install deps, create DB, setup assets)
mix setup
```

**Step 2: Add PEARL_DB_PORT to Environment Variables**

In `CLAUDE.md`, in the Environment Variables code block (lines 90-105), add after the Storage section:

```bash
# Database (Docker)
PEARL_DB_PORT=5432              # Override if port 5432 is in use
```

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add docker compose and PEARL_DB_PORT to CLAUDE.md"
```

---

### Task 5: Final verification

**Step 1: Run mix format**

Run from `pearl/` directory: `mix format`
Expected: No changes (config files should already be formatted).

**Step 2: Run full test suite**

Run from `pearl/` directory: `mix test`
Expected: All tests pass.

**Step 3: Run precommit checks**

Run from `pearl/` directory: `mix precommit`
Expected: All checks pass (compile, format, test).

**Step 4: Commit any formatting fixes (if needed)**

Only if mix format made changes:

```bash
git add -A
git commit -m "style: format config files"
```
