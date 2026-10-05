#!/usr/bin/env bash
# Validates a Release Watcher scan handoff file against its fixed schema
# before the write-capable notify job is allowed to read it.
#
# The scan job that produces this file reads contributor-controlled
# upstream content (source PR titles, bodies, diffs) with a model that has
# Write access to disk. The notify job that consumes it holds
# issue-create/edit/comment credentials. This script is the machine-checked
# gate between the two: a malformed file, or one with fields of the wrong
# shape, fails here -- in plain jq, not by asking the notify session to use
# good judgment about data it should never have had reason to distrust in
# the first place. Run once at the end of the scan job (before the artifact
# upload) and again at the start of the notify job (after the artifact
# download), so a compromised scan job can't skip its own check.
#
# Usage: validate-watcher-summary.sh <minor|major> <path-to-summary.json>
# Optional, stricter checks (each only when set):
#   WATCHER_TARGET_VERSION  every confirmed item's target_version must equal it
#                           (the run's own computed version, never the model's)
#   WATCHER_PR_URL_RE       every source_prs url must match this regex
#   WATCHER_STRICT=1        non-empty source_prs, titles, and reasons; length
#                           caps on titles, evidence, and completeness details
set -euo pipefail

KIND="${1:?usage: validate-watcher-summary.sh <minor|major> <summary.json path>}"
FILE="${2:?usage: validate-watcher-summary.sh <minor|major> <summary.json path>}"

[ -s "$FILE" ] || { echo "validate-watcher-summary.sh: $FILE is missing or empty." >&2; exit 1; }
jq empty "$FILE" || { echo "validate-watcher-summary.sh: $FILE is not valid JSON." >&2; exit 1; }

case "$KIND" in
  minor)
    SCHEMA='
      (.scanned | type == "object") and
      (.filtered_count | type == "number") and
      (.verified_counts | type == "object") and
      (.verified_counts.held | type == "number") and
      (.verified_counts.ruled_out | type == "number") and
      (.verified_counts.needs_a_look | type == "number") and
      (.verified_counts.confirmed | type == "number") and
      (.confirmed_items | type == "array") and
      (all(.confirmed_items[]?;
        (.source_prs | type == "array") and
        (all(.source_prs[]?; (.repo | type == "string") and (.number | type == "number") and (.url | type == "string"))) and
        (.evidence | type == "string") and
        (.target_version | type == "string") and
        (.suggested_title | type == "string") and
        (.breaking | type == "boolean") and
        (.tracking_issue == null or ((.tracking_issue.repo | type == "string") and (.tracking_issue.number | type == "number"))) and
        (.original_pr == null or ((.original_pr.repo | type == "string") and (.original_pr.number | type == "number")))
      )) and
      (.reviewed_items | type == "array") and
      (all(.reviewed_items[]?;
        (.status | IN("held", "ruled_out", "needs_a_look")) and
        (.source_prs | type == "array") and
        (all(.source_prs[]?; (.repo | type == "string") and (.number | type == "number") and (.url | type == "string"))) and
        (.reason | type == "string")
      ))
    '
    ;;
  major)
    SCHEMA='
      (.scanned | type == "object") and
      (.excluded_as_minor | type == "object") and
      (.excluded_as_minor.backport_found | type == "number") and
      (.excluded_as_minor.bugfix_type | type == "number") and
      (.verified_counts | type == "object") and
      (.verified_counts.held | type == "number") and
      (.verified_counts.ruled_out | type == "number") and
      (.verified_counts.needs_a_look | type == "number") and
      (.verified_counts.confirmed | type == "number") and
      (.confirmed_items | type == "array") and
      (all(.confirmed_items[]?;
        (.source_prs | type == "array") and
        (all(.source_prs[]?; (.repo | type == "string") and (.number | type == "number") and (.url | type == "string"))) and
        (.evidence | type == "string") and
        (.target_version | type == "string") and
        (.suggested_title | type == "string") and
        (.breaking | type == "boolean") and
        (.tracking_issue == null or ((.tracking_issue.repo | type == "string") and (.tracking_issue.number | type == "number"))) and
        (.original_pr == null or ((.original_pr.repo | type == "string") and (.original_pr.number | type == "number")))
      )) and
      (.reviewed_items | type == "array") and
      (all(.reviewed_items[]?;
        (.status | IN("held", "ruled_out", "needs_a_look")) and
        (.source_prs | type == "array") and
        (all(.source_prs[]?; (.repo | type == "string") and (.number | type == "number") and (.url | type == "string"))) and
        (.reason | type == "string")
      )) and
      (.completeness_checks | type == "array") and
      (all(.completeness_checks[]?;
        (.issue_number | type == "number" and . > 0 and . == floor) and
        (.tracked_prs | type == "array" and length > 1) and
        (all(.tracked_prs[]; (.repo | type == "string" and test("^[A-Za-z0-9_.-]+$")) and (.number | type == "number" and . > 0 and . == floor))) and
        (.classification | IN("COMPLETE", "INCOMPLETE", "UNCLEAR")) and
        (.details | type == "string")
      ))
    '
    ;;
  *)
    echo "validate-watcher-summary.sh: unknown kind '$KIND' -- expected 'minor' or 'major'." >&2
    exit 1
    ;;
esac

EXTRA='true'
if [ -n "${WATCHER_TARGET_VERSION:-}" ]; then
  EXTRA+=' and all(.confirmed_items[]?; .target_version == $tv)'
fi
if [ -n "${WATCHER_PR_URL_RE:-}" ]; then
  EXTRA+=' and all((.confirmed_items[]?, .reviewed_items[]?) | .source_prs[]?; .url | test($urlre))'
fi
if [ "${WATCHER_STRICT:-0}" = "1" ]; then
  EXTRA+='
    and (.filtered_count | type == "number")
    and all(.scanned[]; type == "number")
    and all(.confirmed_items[]?;
      (.source_prs | length > 0) and (.suggested_title | test("\\S")) and (.suggested_title | length <= 200)
      and (.evidence | length <= 4000))
    and all(.reviewed_items[]?; (.source_prs | length > 0) and (.reason | test("\\S")))
    and all(.completeness_checks[]?; (.details | test("\\S")) and (.details | length <= 4000))'
fi
SCHEMA="($SCHEMA) and ($EXTRA)"

if ! jq -e --arg tv "${WATCHER_TARGET_VERSION:-}" --arg urlre "${WATCHER_PR_URL_RE:-}" "$SCHEMA" "$FILE" > /dev/null; then
  echo "validate-watcher-summary.sh: $FILE does not match the expected '$KIND' watcher schema -- refusing to hand it to the write-capable session." >&2
  exit 1
fi

echo "validate-watcher-summary.sh: $FILE matches the '$KIND' watcher schema."
