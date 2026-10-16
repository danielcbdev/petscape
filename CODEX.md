# Using OpenAI Codex with PetScape

This file is **documentation for humans**. Codex does not load `CODEX.md` automatically — it reads
`AGENTS.md` files (global `~/.codex/AGENTS.md`, then the repository root down to the working
directory). All shared rules therefore live in [AGENTS.md](AGENTS.md); do not copy them here.

## How Codex picks up instructions

- Root [AGENTS.md](AGENTS.md) applies to the whole repository.
- If a subdirectory ever needs extra rules (e.g. `Packages/PetScapeKit/AGENTS.md`), add a small
  nested `AGENTS.md` that only adds to the root file. Avoid this unless a real need appears.
- Keep `AGENTS.md` below Codex's project-doc size limit (32 KiB by default); details belong in `docs/`.

## Environment notes

- **Local Codex CLI / IDE on macOS** can run everything (`make test-core`, `make build`, `xcodebuild`).
  In sandboxed modes, `xcodebuild` may need write access to `DerivedData`; run with workspace-write
  and approve as needed.
- **Codex cloud tasks run in Linux containers**: the app, AppKit, Core Animation and `xcodebuild` are not
  available there. Use cloud tasks only for documentation or for reviewing logic; do not report
  builds/tests as passing unless they ran on macOS.
- Verification for visual behavior (overlay, click-through, Dock alignment) requires a human or a
  local agent running the app; say "not verified" otherwise.

## Suggested prompt shape

```text
Read AGENTS.md. Implement task T4.4 from docs/planning/task-breakdown.md.
Follow its acceptance criteria. Run `make test-core`. Do not commit.
Report changes, verification, limitations and follow-ups.
```
