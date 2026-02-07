# Docker Compose Database Setup

## Problem

Setting up Pearl requires installing PostgreSQL 18+ and pgvector natively, which is error-prone for new users. Port 5432 often conflicts with other local Postgres instances, with no graceful handling.

## Decision

Add docker-compose for Postgres-only (not the full app), make the DB port configurable via `PEARL_DB_PORT`, and surface clear error messages on connection failure.

## Design

### 1. docker-compose.yml (project root)

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

volumes:
  pearl_pgdata:
```

- `pgvector/pgvector:pg18` — Postgres 18 with pgvector pre-installed
- Port configurable via `PEARL_DB_PORT` env var, defaults to 5432
- Named volume for data persistence across restarts

### 2. Dev/Test Config Changes

`config/dev.exs` and `config/test.exs` read `PEARL_DB_PORT`:

```elixir
config :pearl, Pearl.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: String.to_integer(System.get_env("PEARL_DB_PORT", "5432")),
  database: "pearl_dev",
  ...
```

No changes to `runtime.exs` — production uses `DATABASE_URL` which includes the port.

### 3. Port Conflict Error Message

In `lib/pearl/repo.ex`, enhance the `init/2` callback to catch `DBConnection.ConnectionError` during startup and print:

```
==> Pearl cannot connect to PostgreSQL on port 5432.

    This usually means:
    1. PostgreSQL is not running — start it with: docker compose up -d
    2. Another service is using port 5432 — set a different port:
       export PEARL_DB_PORT=5433
       Then restart both docker-compose and the Phoenix server.

    Current config: localhost:5432 (override with PEARL_DB_PORT)
```

### 4. README Updates

Docker-first setup instructions:

1. `docker compose up -d` — start Postgres
2. `export OPENROUTER_API_KEY=sk-...` — configure LLM
3. `mix setup && mix phx.server` — run the app

Port conflict section explains `PEARL_DB_PORT`. Native Postgres mentioned as a brief alternative.

### 5. CLAUDE.md Updates

Update development commands section to include `docker compose up -d` in the setup flow.

## Files Changed

| File | Change |
|------|--------|
| `docker-compose.yml` | New — Postgres 18 + pgvector service |
| `config/dev.exs` | Add `port:` from `PEARL_DB_PORT` |
| `config/test.exs` | Add `port:` from `PEARL_DB_PORT` |
| `lib/pearl/repo.ex` | Connection error message in `init/2` |
| `README.md` | Docker-first setup instructions |
| `CLAUDE.md` | Update dev commands |

## Scope Boundaries

- No Dockerfile for the Elixir app (future work)
- No docker-compose profiles for full-stack containers
- Production config unchanged (`DATABASE_URL` already handles this)
