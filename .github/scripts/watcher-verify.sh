#!/usr/bin/env bash
# Verify step for the Minor/Major Release Watchers: one fresh Claude Code
# session per chunk written by `watcher-prefetch.sh bundle`, so any number
# of PRs is reviewed without one session growing until it compacts (and
# drops context). Verdicts from every chunk are merged into one file for
# watcher-assemble.sh, and per-chunk usage goes to the job summary.
#
# Usage: watcher-verify.sh "<mode note for the prompt>"
# Env:   OUT, CLAUDE_CODE_OAUTH_TOKEN, MAX_TURNS (per chunk, default 30),
#        GITHUB_STEP_SUMMARY (optional).
set -euo pipefail

NOTE="${1:?mode note}"
OUT="${OUT:?OUT is required}"
MAX_TURNS="${MAX_TURNS:-30}"
SCHEMA=$(jq -c . .ai/release-watchers/verdicts.schema.json)

# Lean, cache-friendly sessions: no CLAUDE.md, memory, skills, MCP, or
# subagents; a five-minute prompt cache (runs finish in minutes, and the
# subscription default of one hour bills cache writes at 2x instead of
# 1.25x).
export CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
export CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1 CLAUDE_CODE_PROMPT_CACHE_TTL=5m
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

echo '[]' > "$OUT/verdicts.list.json"
chunks=("$OUT"/chunk-*)
total=${#chunks[@]}
[ -d "${chunks[0]:-}" ] || total=0
{
  echo "### Model usage"
  echo "| Chunk | Candidates | Turns | Cost (USD, est.) | Duration (s) | Result |"
  echo "|---|---|---|---|---|---|"
} > "$OUT/usage.md"

n=0
for dir in "${chunks[@]}"; do
  [ -d "$dir" ] || continue
  n=$((n + 1))
  files=$(ls "$dir"/index.md "$dir"/bundle-*.md 2>/dev/null | paste -sd' ' -)
  count=$(cat "$dir/count")
  prompt="$NOTE
Session $n of $total. Candidates in this session: $count (every [candidate] line in index.md).
Read all of these files in parallel first:
$files"

  status=ok
  # The model gets Read and Grep only. Reads stay inside this checkout and
  # $OUT; /proc is denied outright so the token in this process's
  # environment cannot be read back.
  if ! claude -p --model claude-sonnet-5-5 --effort high --max-turns "$MAX_TURNS" \
      --system-prompt-file .ai/release-watchers/scan-system-prompt.md \
      --add-dir "$OUT" \
      --tools Read,Grep --allowedTools Read Grep \
      --disallowedTools "mcp__*" Agent "Read(//proc/**)" "Grep(//proc/**)" \
      --disable-slash-commands --setting-sources project --no-session-persistence \
      --json-schema "$SCHEMA" --output-format json "$prompt" \
      > "$dir/result.json" 2> "$dir/stderr.txt"; then
    status=failed
    echo "::warning::Verify session $n of $total failed; its candidates fall back to needs_a_look."
  fi
  if jq -e '.structured_output.verdicts | type == "array"' "$dir/result.json" > /dev/null 2>&1; then
    jq -c '.structured_output.verdicts' "$dir/result.json" > "$dir/verdicts.json"
    jq -s '.[0] + .[1]' "$OUT/verdicts.list.json" "$dir/verdicts.json" > "$OUT/verdicts.tmp"
    mv "$OUT/verdicts.tmp" "$OUT/verdicts.list.json"
  else
    status="$status, no verdicts"
  fi
  jq -r --arg c "$n/$total" --arg k "$count" --arg s "$status" \
    '"| \($c) | \($k) | \(.num_turns // "-") | \(.total_cost_usd // 0 | . * 1000 | round / 1000) | \((.duration_ms // 0) / 1000 | round) | \($s) |"' \
    "$dir/result.json" 2>/dev/null >> "$OUT/usage.md" \
    || echo "| $n/$total | $count | - | - | - | $status |" >> "$OUT/usage.md"
done

jq -c '{verdicts: .}' "$OUT/verdicts.list.json" > "$OUT/verdicts.json"
[ "$total" -eq 0 ] && echo "No PRs in the window; no verify session ran." >> "$OUT/usage.md"
cat "$OUT/usage.md"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$OUT/usage.md" >> "$GITHUB_STEP_SUMMARY"
exit 0
