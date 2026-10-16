# ADR-0014: AGENTS.md as the single source of agent instructions

- Status: Proposed
- Date: 2026-10-16
- Related: [AGENTS.md](../../AGENTS.md), [CLAUDE.md](../../CLAUDE.md), [CODEX.md](../../CODEX.md)

## Context

Development uses Claude Code, OpenAI Codex and Cursor. Each tool reads instructions differently:
Codex reads `AGENTS.md` files (repository root down to the working directory; it does **not** read a
`CODEX.md` by convention). Claude Code reads `CLAUDE.md` and supports `@path` imports. Cursor reads
project rules in `.cursor/rules/*.mdc` (frontmatter: `description`, `globs`, `alwaysApply`) and also
supports `AGENTS.md`. The legacy `.cursorrules` file is deprecated.

## Problem

Keep instructions consistent across tools without duplicating large blocks that drift apart.

## Alternatives

1. Full instructions duplicated per tool → drift.
2. Symlinks (`CLAUDE.md → AGENTS.md`) → no room for tool-specific notes; symlink handling varies.
3. **`AGENTS.md` canonical; thin tool-specific files that import or reference it.**

## Decision

- `AGENTS.md` holds all shared rules (project, stack, architecture summary, conventions, process,
  quality bar). Keep it under ~32 KiB (Codex's default project-doc size limit).
- `CLAUDE.md` imports `@AGENTS.md` and adds only Claude Code specifics (permissions, plan mode,
  subagents usage).
- `CODEX.md` is human documentation explaining how Codex is used here; it states that Codex reads
  `AGENTS.md`.
- `.cursor/rules/*.mdc`: one always-applied rule pointing to `AGENTS.md`, plus small glob-scoped
  rules (Swift sources, tests, assets/manifests, docs) that add file-type checklists, not new policy.
- `.claude/settings.json` holds shared, conservative permissions (no secrets, no personal paths).

## Rationale

One canonical file keeps policy consistent; tool files only adapt delivery.

## Consequences

- Any policy change is made in `AGENTS.md` first; tool files change only if delivery changes.
- Reviews check that `.mdc` rules do not contradict `AGENTS.md`.

## Risks

| Risk | Mitigation |
|---|---|
| Tool loading behavior changes | Re-verify at each major tool update; CODEX.md/CLAUDE.md note the assumption |
| AGENTS.md grows too large | Keep it a map that links to `docs/`; details live in docs |
