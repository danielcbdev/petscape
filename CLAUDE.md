# CLAUDE.md

@AGENTS.md

The import above is the shared, canonical instruction set. Everything below only adds Claude
Code–specific delivery details and must not contradict it.

## Claude Code specifics

- **Start of session:** read `AGENTS.md` (imported), then the milestone status in
  `docs/planning/milestones.md` and the task you were given. Do not rely on personal or plugin
  memory for project facts; the docs are the source of truth. If memory and docs disagree, trust
  the docs and mention the discrepancy.
- **Plan first** for any task touching more than one module or any platform behavior: use plan mode
  (or present a short plan) and wait for approval before editing.
- **Subagents** are fine for read-only exploration and reviews. Do not delegate edits to several
  agents on the same files at once.
- **Permissions:** shared rules live in `.claude/settings.json` (read-only git commands and `make`
  targets allowed; commits/pushes ask; edits to original art under `assets/` denied). Do not widen
  them; personal overrides go in `.claude/settings.local.json` (git-ignored).
- **Commits:** only when explicitly asked (see AGENTS.md §14). Never use `--no-verify`, never force-push.
- **Verification:** for visual/platform behavior (overlay, click-through, Dock alignment) state what
  you verified by running the app and what remains for manual testing. Never claim visual results
  you did not observe.
- **Xcode project:** prefer folder-synchronized groups; avoid hand-editing `project.pbxproj`. If an
  edit there is unavoidable, keep it minimal and mention it in the report.
- **Long builds/tests:** run `xcodebuild` in the background when it may exceed two minutes.
