#!/usr/bin/env bash
# Copy a Claude Code transcript snapshot to .lathe/runs/<session_id>/.
#
# Three modes, dispatched on hook_event_name:
#   Stop          — copy parent transcript to .lathe/runs/<sid>/transcript.jsonl
#   PreCompact    — same destination; no flush race so skip the wait
#   SubagentStop  — copy subagent transcript (agent_transcript_path, distinct
#                   from the parent's transcript_path) to
#                   .lathe/runs/<sid>/subagents/agent-<agent_id>.jsonl
#
# Why size-stability watermark for Stop / SubagentStop: the hook fires before
# Claude Code finishes flushing the assistant turn(s) to disk. A single turn
# can produce multiple assistant records (e.g. extended thinking written as a
# standalone assistant followed by a text-response assistant — both with
# stop_reason=end_turn). We poll the source file size; two consecutive
# unchanged reads at 0.5s intervals = "writer done."
#
# Failures are silent (exit 0) so we never disturb the main flow.

set -uo pipefail

INPUT="$(cat)"

# Materialized to <lathe-managed-wt>/hooks/, so parent is that worktree root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty')"
HOOK_EVENT="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty')"

[ -z "$SESSION_ID" ] && exit 0

DEST_DIR="$REPO_ROOT/.lathe/runs/$SESSION_ID"

# Resolve SOURCE / DEST per hook type.
SOURCE=""
DEST=""
DO_WAIT=1
STATUS=""

case "$HOOK_EVENT" in
  Stop|PreCompact)
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')"
    DEST="$DEST_DIR/transcript.jsonl"
    STATUS="$DEST_DIR/transcript.copy-status.json"
    [ "$HOOK_EVENT" = "PreCompact" ] && DO_WAIT=0
    ;;
  SubagentStop)
    AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty')"
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty')"
    [ -z "$AGENT_ID" ] && exit 0
    DEST="$DEST_DIR/subagents/agent-$AGENT_ID.jsonl"
    STATUS="$DEST_DIR/subagents/agent-$AGENT_ID.copy-status.json"
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$SOURCE" ] && exit 0
SOURCE="${SOURCE/#\~/$HOME}"
[ -z "$STATUS" ] && STATUS="$DEST.copy-status.json"

mkdir -p "$(dirname "$DEST")"

write_status() {
  local status="$1"
  local detail="$2"
  jq -n \
    --arg status "$status" \
    --arg detail "$detail" \
    --arg hook_event "$HOOK_EVENT" \
    --arg session_id "$SESSION_ID" \
    --arg source "$SOURCE" \
    --arg dest "$DEST" \
    '{
      status: $status,
      detail: $detail,
      hook_event: $hook_event,
      session_id: $session_id,
      source: $source,
      dest: $dest
    }' > "$STATUS" 2>/dev/null || true
}

# Claude may report transcript_path before the file is visible on disk. Wait a
# little before deciding it is unavailable.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$SOURCE" ] && break
  sleep 0.5
done

if [ ! -f "$SOURCE" ]; then
  write_status "missing_source" "transcript source file was not present; session persistence may be disabled"
  exit 0
fi

# Initial snapshot — guarantees a copy exists even if we time out.
cp -f "$SOURCE" "$DEST"

# PreCompact: no race, done.
if [ "$DO_WAIT" = "0" ]; then
  rm -f "$STATUS" 2>/dev/null || true
  exit 0
fi

# Stop / SubagentStop: wait for source size to stabilize.
sleep 0.5
PREV_SIZE="$(wc -c < "$SOURCE" 2>/dev/null | tr -d ' ')"
STABLE_HITS=0

for _ in 1 2 3 4 5 6; do
  sleep 0.5
  CURRENT_SIZE="$(wc -c < "$SOURCE" 2>/dev/null | tr -d ' ')"
  if [ "$CURRENT_SIZE" = "$PREV_SIZE" ]; then
    STABLE_HITS=$((STABLE_HITS + 1))
    if [ "$STABLE_HITS" -ge 2 ]; then
      cp -f "$SOURCE" "$DEST"
      rm -f "$STATUS" 2>/dev/null || true
      exit 0
    fi
  else
    STABLE_HITS=0
  fi
  PREV_SIZE="$CURRENT_SIZE"
done

# Timeout — final cp captures whatever exists now.
cp -f "$SOURCE" "$DEST"
write_status "timeout_after_copy" "transcript source size did not stabilize before timeout; final snapshot was copied"
exit 0
