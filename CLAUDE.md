# CLAUDE.md - Godot MCP Repository Guidance

## Scope

- This file codifies the repository-level token-efficiency development rules validated during the capability-gap closure goal.
- Preserve stronger existing policy from `AGENTS.md`; do not weaken unrelated workflow or safety requirements.

## Token-Efficiency Rules

- Treat MCP token efficiency as a repository-wide rule for existing tools, new tools, docs, tests, and future capability-gap work.
- Default responses may be smaller, but they must never silently imply completeness when data is omitted.
- Any bounded or partial result must expose explicit continuation metadata such as `truncated`, `has_more`, `next_cursor`, `next_max_results`, or another domain-appropriate equivalent.
- Prefer bounded output and progressive disclosure from the start: `max_items`, `max_results`, `max_depth`, `count/offset`, summary/detail shapes, and stable rerun hints should be built into tool design when results can grow large.
- Do not force unnecessary extra round trips for small results. Small complete results should still return directly.
- High-risk writes, destructive actions, and final judgments must fetch fuller detail when summary data is insufficient.
- When retrofitting an existing tool, keep exact-fit pages truthful: reaching a limit is not enough to claim `has_more=true` unless there is concrete evidence that more data exists.
- Tool docs and tests must stay aligned with these rules. Any new truncation, pagination, summary/detail, or rerun-hint contract must be reflected in `docs/current/tools-reference.md` and covered by focused regression tests.
