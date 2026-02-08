# Docker Compose Database Setup

## Problem

Setting up Pearl requires installing PostgreSQL 18+ and pgvector natively, which is error-prone for new users. Port 5432 often conflicts with other local Postgres instances, with no graceful handling.

## Decision

Add docker-compose for Postgres-only (not the full app), make the DB port configurable via `PEARL_DB_PORT`, and rely on Phoenix's built-in connection error messages.

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
      - pearl_pgdata:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pearl_pgdata:
```

- `pgvector/pgvector:pg18` — Postgres 18 with pgvector pre-installed
- Port configurable via `PEARL_DB_PORT` env var, defaults to 5432
- Named volume for data persistence across restarts
- Healthcheck enables `docker compose up -d --wait` to block until ready

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

### 3. README Updates

- Replace native Postgres prerequisites with Docker-first: `docker compose up -d`
- Add `docker compose up -d` as a setup step (after clone, before LLM config)
- Mention `PEARL_DB_PORT` for port conflict resolution
- Keep native install as a brief alternative
- Remove redundant `cd assets && npm install` step (`mix setup` handles it)

### 4. CLAUDE.md Updates

- Add `docker compose up -d` to the Development Commands setup flow
- Add `PEARL_DB_PORT` to the Environment Variables section

## Files Changed

| File | Change |
|------|--------|
| `docker-compose.yml` | New — Postgres 18 + pgvector service with healthcheck |
| `config/dev.exs` | Add `port:` from `PEARL_DB_PORT` |
| `config/test.exs` | Add `port:` from `PEARL_DB_PORT` |
| `README.md` | Docker-first setup instructions |
| `CLAUDE.md` | Update dev commands and env vars |

## Scope Boundaries

- No Dockerfile for the Elixir app (future work)
- No docker-compose profiles for full-stack containers
- No custom error messages in Repo — Phoenix defaults are clear enough
- Production config unchanged (`DATABASE_URL` already handles this)
