#!/usr/bin/env bash
# Posts one Slack message when a Major Release Watcher run finishes: pass or
# fail, the failed job and step names, a link to the run, and the issues the
# notify step created (or would create, in a dry run) with their links.
# Runs in the final `report` job (`if: always()`), so it also fires when an
# earlier job failed. Off-week runs (the cron fires every Monday, work happens
# on even weeks) finish as a no-op success and send nothing.
#
# Usage: watcher-slack-report.sh <report-file>
#   report-file  text written by watcher-notify.sh (SLACK_FILE); may be missing
# Env:   WATCHER_NAME, VERSION, RUN_THIS_WEEK ("true" on a working run),
#        SETUP_RESULT, SCAN_RESULT, NOTIFY_RESULT (job results from `needs`),
#        DRY_RUN ("true" for a preview run), RUN_URL, RUN_ID, GITHUB_REPOSITORY,
#        GH_TOKEN (to name the failed steps), SLACK_WEBHOOK_URL,
#        PRINT_ONLY=1 (print the message instead of posting, for local tests).
set -euo pipefail

REPORT="${1:-}"
NAME="${WATCHER_NAME:-Major Release Watcher}"
REPO="${GITHUB_REPOSITORY:-}"

failed=false
for r in "${SETUP_RESULT:-}" "${SCAN_RESULT:-}" "${NOTIFY_RESULT:-}"; do
  case "$r" in failure|cancelled) failed=true ;; esac
done

if [ "$failed" = "false" ] && [ "${RUN_THIS_WEEK:-}" != "true" ]; then
  echo "Off-week run, nothing to report."; exit 0
fi

mode=""; [ "${DRY_RUN:-}" = "true" ] && mode=" (dry run)"
ver=""; [ -n "${VERSION:-}" ] && ver=" for ${VERSION}"

if [ "$failed" = "true" ]; then
  head=":x: *${NAME}* (${REPO#*/}) failed${ver}${mode}"
  steps=""
  if [ -n "${RUN_ID:-}" ] && [ -n "$REPO" ]; then
    steps=$(gh api "repos/${REPO}/actions/runs/${RUN_ID}/jobs" --paginate \
      --jq '.jobs[] | select(.conclusion == "failure") | "\(.name): " + ([.steps[]? | select(.conclusion == "failure") | .name] | join(", "))' 2>/dev/null || true)
  fi
  [ -n "$steps" ] && detail=$'\nFailed step(s):\n'"$(sed 's/^/• /' <<< "$steps")" || detail=$'\nSetup, scan and notify results: '"${SETUP_RESULT:-?}, ${SCAN_RESULT:-?}, ${NOTIFY_RESULT:-?}"
else
  head=":white_check_mark: *${NAME}* (${REPO#*/}) passed${ver}${mode}"
  detail=""
fi

# The report file is a summary line plus one "<issue name><TAB><url>" row per
# issue. Rows become a two-column table (issue name, linked issue number);
# any other line is plain text.
summary=""; rows=""
if [ -n "$REPORT" ] && [ -s "$REPORT" ]; then
  summary=$(grep -v $'\t' "$REPORT" || true)
  rows=$(grep $'\t' "$REPORT" || true)
elif [ "$failed" = "false" ]; then
  summary="No issues created."
fi

link_line=""; [ -n "${RUN_URL:-}" ] && link_line="<${RUN_URL}|View run>"

# Slack treats & < > as markup, and issue titles are model-written.
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# Plain-text version: the notification preview, and the fallback for clients
# that cannot render blocks.
plain="${head}${detail}"
[ -n "$summary" ] && plain="${plain}"$'\n\n'"$(esc <<< "$summary")"
[ -n "$rows" ] && plain="${plain}"$'\n'"$(awk -F'\t' '{ n = $2; sub(/.*\//, "", n); print "• " $1 (n != "" ? " (#" n ")" : "") ($2 != "" ? ": " $2 : "") }' <<< "$rows" | esc)"
[ -n "$link_line" ] && plain="${plain}"$'\n'"${link_line}"

# Block Kit: header text, then the table as section "fields" (two per row,
# at most 10 fields per section), then the run link.
blocks=$(jq -n --arg head "${head}${detail}" --arg summary "$(esc <<< "$summary")" \
    --arg link "$link_line" --arg rows "$rows" '
  def cell($t): {type: "mrkdwn", text: $t};
  def esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
  ($rows | split("\n") | map(select(. != "") | split("\t"))) as $all
  | ($all[0:100]) as $r
  | ([ {type: "section", text: {type: "mrkdwn", text: ($head + (if $summary != "" then "\n\n" + $summary else "" end))}} ]
     + (if ($r | length) > 0 then
          ([ cell("*Issue*"), cell("*Number*") ]
           + [ $r[] | (.[0] | esc) as $name | ((.[1] // "") | sub(".*/"; "")) as $n
               | cell($name),
                 cell(if (.[1] // "") != "" then "<" + .[1] + "|#" + $n + ">" else "-" end) ])
          | [ range(0; length; 10) as $i | .[$i:$i+10] ]
          | map({type: "section", fields: .})
        else [] end)
     + (if ($all | length) > 100 then [ {type: "context", elements: [cell("and " + (($all | length) - 100 | tostring) + " more, see the run")]} ] else [] end)
     + (if $link != "" then [ {type: "context", elements: [cell($link)]} ] else [] end))')

if [ "${PRINT_ONLY:-}" = "1" ]; then
  printf '%s\n\n--- blocks ---\n%s\n' "$plain" "$(jq -c . <<< "$blocks")"; exit 0
fi
if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "Slack not configured (missing SLACK_WEBHOOK_URL secret); skipping."; exit 0
fi
payload=$(jq -n --arg text "$plain" --argjson blocks "$blocks" '{text: $text, blocks: $blocks}')
resp=$(curl -sS -X POST "$SLACK_WEBHOOK_URL" -H "Content-type: application/json; charset=utf-8" --data "$payload" || true)
echo "$resp"
if [ "$resp" != "ok" ]; then
  # Blocks rejected (invalid_blocks and the like): still deliver the text.
  echo "::warning::Slack rejected the formatted message ('$resp'); resending as plain text."
  curl -sS -X POST "$SLACK_WEBHOOK_URL" -H "Content-type: application/json; charset=utf-8" \
    --data "$(jq -n --arg text "$plain" '{text: $text}')"
fi
