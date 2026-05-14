#!/usr/bin/env bash
# Append a structured event to .lathe/runs/<session_id>/events.jsonl.
# Hook input (JSON) arrives on stdin. Anthropic's hook contract says stdout for
# SessionStart / UserPromptSubmit is injected into Claude context, so we MUST
# write the log line to a file only and emit nothing on stdout.
#
# Hooks fire concurrently (PreToolUse / PostToolUse / SubagentStart-Stop in
# bursts). POSIX append (>>) is atomic only for writes <= PIPE_BUF (~4KB on
# macOS / Linux). Hook payloads frequently exceed that — tool_response with
# large file content, transcript snippets, etc. — so unsynchronized appends
# interleave and corrupt the JSONL with literal newlines mid-record. We
# serialize via an mkdir-based mutex (mkdir is POSIX-atomic; works on macOS
# BSD and Linux without external tools like flock).

set -euo pipefail

EVENT="${1:?event name required}"
INPUT="$(cat)"

# This script is materialized to <lathe-managed-wt>/hooks/log.sh, so its parent
# dir is the Lathe-managed worktree root (where .lathe/runs/ lives).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"')"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

LOG_DIR="$REPO_ROOT/.lathe/runs/$SESSION_ID"
mkdir -p "$LOG_DIR"

# Build the line first so the locked region is just the append.
LINE="$(printf '%s' "$INPUT" \
  | jq -c --arg ts "$TS" --arg ev "$EVENT" \
      '{ts: $ts, event: $ev, session_id: (.session_id // null), payload: .}')"

# Acquire mutex (mkdir is atomic). Spin briefly; cap at ~5s to avoid hang.
LOCK_DIR="$LOG_DIR/.events.lock"
TRIES=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -gt 500 ]; then
    # Give up rather than block hook indefinitely. Stale lock will be
    # cleaned up on next successful acquisition.
    rmdir "$LOCK_DIR" 2>/dev/null || true
    break
  fi
  sleep 0.01
done

trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
printf '%s\n' "$LINE" >> "$LOG_DIR/events.jsonl"

exit 0
