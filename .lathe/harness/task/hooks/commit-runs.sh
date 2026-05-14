#!/usr/bin/env bash
# commit-runs.sh — auto-commit a session's .lathe/runs/<sid>/ directory after task finishes.
#
# Wired in as a Stop hook. Logs live under the active Lathe-managed worktree's
# .lathe/runs/ directory and are committed on that same branch.
#
# Failures are silent (exit 0) — never disturb the main flow.

set -uo pipefail

INPUT="$(cat)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty')"
[ -z "$SESSION_ID" ] && exit 0

# Materialized to <lathe-managed-wt>/hooks/, parent is that worktree root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT" || exit 0
RUN_DIR=".lathe/runs/$SESSION_ID"
[ ! -d "$RUN_DIR" ] && exit 0

# Lock to serialize commits across concurrent sessions in the same repo.
# /tmp because worktree .git/ is a file (not dir), can't mkdir inside.
LOCK_KEY="$(printf '%s' "$REPO_ROOT" | tr '/' '_')"
LOCK_DIR="/tmp/lathe-commit-${LOCK_KEY}.lock"
TRIES=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -gt 500 ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    break
  fi
  sleep 0.01
done
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

git add "$RUN_DIR" 2>/dev/null || exit 0
# Bail if nothing actually staged.
git diff --cached --quiet -- "$RUN_DIR" 2>/dev/null && exit 0

git -c user.email=lathe@local -c user.name=lathe-runs \
    commit -q -m "runs: $SESSION_ID" -- "$RUN_DIR" 2>/dev/null || true

exit 0
