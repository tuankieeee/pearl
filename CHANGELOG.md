# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/existential-birds/pearl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/existential-birds/pearl/releases/tag/v0.1.0
