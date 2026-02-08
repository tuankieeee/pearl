# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-02-08

### Added

- Add global navbar with search and navigation
- Remove WikiLive internal navbar, integrate with global navbar
- Add navbar assigns to HomeLive, remove duplicate header
- Add placeholder SettingsLive page
- Wrap routes in live_session with NavbarHook
- Rewrite app/1 layout with global navbar
- Add Repositories.search/1 for navbar search
- Add NavbarHook for global search event handling
- Make DB port configurable via PEARL_DB_PORT env var
- Add docker-compose for Postgres 18 + pgvector

### Fixed

- Preserve search input value and remove dead mobile button
- Update streaming tests for new ask button selector
- Remove unused inner_block slot and fix breadcrumb test
- Use @inner_content instead of render_slot(@inner_block) in layout
- Use pg18-compatible volume mount path in docker-compose

### Changed

- Use Phoenix form component for navbar search

### Documentation

- Add global navbar design document and implementation plan
- Fix plan doc inconsistencies from PR review
- Add docker compose and PEARL_DB_PORT to CLAUDE.md
- Docker-first setup instructions in README
- Add Docker Postgres setup implementation plan and design

### Other

- Remove global navbar plan docs
- Add .beagle/ to gitignore

## [0.1.0] - 2026-02-07

### Added

- Add repo metadata display and syntax highlighting
- Show per-repo progress and fetch metadata in parallel
- Switch to dark-only luxury theme with redesigned home layout
- Redesign chat panel and add docker-postgres design doc
- Redesign chat panel with wider layout, premium styling, and auto-focus
- Initial Pearl wiki app with LLM-powered wiki generation and RAG Q&A

### Fixed

- Self-host Google Fonts instead of external links in layout
- Prevent question duplication in chat history
- Address CodeRabbit review feedback
- Improve type safety and task linking robustness
- Propagate stream/batch errors and harden symlink protection
- Update streaming test selectors to match redesigned chat UI
- Chain repo struct through status updates to prevent stale state
- Harden code from review findings across providers, web, and wiki
- Harden code with typespecs, encapsulation, and error handling
- Address code quality review findings
- Improve code quality with DRY refactoring and error handling
- Harden security and improve robustness
- Add typespecs, fix linked task handling, and clean up dead code
- Revert default model back to gpt-5.2
- Address code quality issues from review
- Improve error handling and code quality
- Remove misleading auth-related comments

### Changed

- Batch embeddings and parallelize file reads
- Harden path traversal, improve error handling, remove unused page controller
- Improve error handling clarity and cleanup dead code

### Documentation

- Add ExDoc config, module docs, function docs, and guide extras
- Add RAG implementation details and research roadmap
- Update RAG roadmap with ottomator-agents strategies
- Simplify RAG roadmap to bullet list
- Expand Pearl Young biography with full accomplishments
- Add DeepWiki badge

### Other

- Add moduledocs, ex_doc dependency, and refactor wiki_live mount
- Ignore tool configs and Phoenix digest files
- Add CODEOWNERS file
- Add .DS_Store and review artifacts to .gitignore

[Unreleased]: https://github.com/existential-birds/pearl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/existential-birds/pearl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/existential-birds/pearl/releases/tag/v0.1.0
