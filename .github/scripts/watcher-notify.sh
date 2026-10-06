#!/usr/bin/env bash
# Notify step for the Minor/Major Release Watchers, in plain bash.
#
# Turns the schema-validated summary.json into issue writes on this repo:
# create or update one tracking issue per confirmed item (de-duplicated by
# hidden markers), comment completeness results (major), comment the scan
# digest, and write slack-digest.txt. No model runs here, so nothing in
# the summary can steer which commands run; model-written text only ever
# lands inside issue bodies via --body-file.
#
# Usage: watcher-notify.sh <minor|major> <summary.json>
# Env:   GH_TOKEN, GITHUB_REPOSITORY, DRY_RUN (true|false),
#        NOTIFY_USERNAMES (comma-separated, optional), GITHUB_STEP_SUMMARY.
# Per-repo settings (defaults are docs-collate's):
#        MARKER_STYLE      "repo" (<!-- p:pr-<repo>#<n> -->) or "number" (<!-- p:pr-<n> -->)
#        DEDUP_PREFIXES    space-separated marker prefixes that count as already
#                          tracked (default "<mode>-watcher"; docs-om adds its
#                          legacy daily-watcher and the other watcher's prefix)
#        TRUSTED_AUTHOR_RE issue authors whose markers count (default github-actions)
#        DIGEST_TITLE, SLACK_FILE (default ./slack-digest.txt)
set -euo pipefail

MODE="${1:?mode}"; SUMMARY="${2:?summary.json}"
REPO="${GITHUB_REPOSITORY:?}"
DRY_RUN="${DRY_RUN:-true}"
PREFIX="${MODE}-watcher"
LABEL_TITLE="$(tr '[:lower:]' '[:upper:]' <<< "${MODE:0:1}")${MODE:1}"
DIGEST_TITLE="${DIGEST_TITLE:-${LABEL_TITLE} Release Watcher -- Scan Digest}"
MARKER_STYLE="${MARKER_STYLE:-repo}"
DEDUP_PREFIXES="${DEDUP_PREFIXES:-$PREFIX}"
TRUSTED_AUTHOR_RE="${TRUSTED_AUTHOR_RE:-github-actions}"
SLACK_FILE="${SLACK_FILE:-slack-digest.txt}"
PREFIXES_JSON=$(jq -cn --arg own "$PREFIX" --arg all "$DEDUP_PREFIXES" '[$own] + ($all | split(" ") | map(select(. != "" and . != $own)))')
# jq: marker text for one PR or tracking issue, in this repo's style.
MK='def mk($p; $kind; $r; $n): if $style == "number" then "<!-- \($p):\($kind)-\($n) -->" else "<!-- \($p):\($kind)-\($r)#\($n) -->" end;'
PREVIEW="$(mktemp)"; SLACK_LINES=()
TMP="$(mktemp -d)"

preview() { printf '%s\n' "$@" >> "$PREVIEW"; }

# Every issue this workflow filed, fetched once and matched locally:
# GitHub search tokenizes "#123" loosely, so exact marker matching is done
# here in jq. Issues created later in this run are appended to the cache.
for p in $DEDUP_PREFIXES; do
  gh issue list --repo "$REPO" --state all --limit 1000 --search "${p} in:body" \
    --json number,body,author
done | jq -s -c --arg a "$TRUSTED_AUTHOR_RE" '
  reduce (.[][] | select(.author.login | test($a)) | {number, body: (.body // "")}) as $i
    ([]; if any(.[]; .number == $i.number) then . else . + [$i] end)' > "$TMP/tracked.json"

find_issue_with() {
  jq -r --arg n "$1" '[.[] | select(.body | contains($n))] | first | .number // empty' "$TMP/tracked.json"
}
remember_issue() {
  jq -c --argjson n "$1" --rawfile b "$2" '. + [{number: $n, body: $b}]' "$TMP/tracked.json" > "$TMP/tracked.new"
  mv "$TMP/tracked.new" "$TMP/tracked.json"
}

assign_args() { [ -n "${NOTIFY_USERNAMES:-}" ] && printf -- '--assignee\n%s\n' "$NOTIFY_USERNAMES"; return 0; }

# ---- 1. Confirmed items -> create or update tracking issues -------------
while read -r item; do
  title=$(jq -r .suggested_title <<< "$item")
  markers=$(jq -r --arg p "$PREFIX" --arg style "$MARKER_STYLE" "$MK"'.source_prs[] | mk($p; "pr"; .repo; .number)' <<< "$item")
  extra=$(jq -r --arg p "$PREFIX" --arg style "$MARKER_STYLE" "$MK"'
      (if .tracking_issue then mk($p; "tracking"; .tracking_issue.repo; .tracking_issue.number) else empty end),
      (if .original_pr then mk($p; "pr"; .original_pr.repo; .original_pr.number) else empty end)' <<< "$item")
  # Every marker that means "already tracked", under each dedup prefix.
  lookup=$(jq -r --argjson ps "$PREFIXES_JSON" --arg style "$MARKER_STYLE" "$MK"'
      ([.source_prs[] | {k: "pr", r: .repo, n: .number}]
       + (if .tracking_issue then [{k: "tracking", r: .tracking_issue.repo, n: .tracking_issue.number}] else [] end)
       + (if .original_pr then [{k: "pr", r: .original_pr.repo, n: .original_pr.number}] else [] end))[]
      | . as $m | $ps[] | mk(.; $m.k; $m.r; $m.n)' <<< "$item")

  existing=""
  while read -r m; do
    [ -z "$m" ] && continue
    existing=$(find_issue_with "$m")
    [ -n "$existing" ] && break
  done <<< "$lookup"

  pr_lines=$(jq -r '.source_prs[] | "- \(.repo)#\(.number): \(.url)"' <<< "$item")
  evidence=$(jq -r .evidence <<< "$item")
  version=$(jq -r .target_version <<< "$item")
  breaking=$(jq -r .breaking <<< "$item")

  if [ -n "$existing" ]; then
    if [ "$existing" = "0" ]; then
      # Dry run: an issue this run would have created; use the remembered body.
      body=$(jq -r '[.[] | select(.number == 0)] | last | .body' "$TMP/tracked.json")
    else
      body=$(gh issue view "$existing" --repo "$REPO" --json body -q .body)
    fi
    # A PR is new to the issue unless a marker for it, under any dedup
    # prefix, is already in the body; new ones get this watcher's marker.
    new_markers=$(jq -c --argjson ps "$PREFIXES_JSON" --arg style "$MARKER_STYLE" "$MK"'
        .source_prs[] | . as $s | [$ps[] | mk(.; "pr"; $s.repo; $s.number)]' <<< "$item" \
      | while read -r alts; do
          seen=false
          while read -r m; do grep -qF -- "$m" <<< "$body" && seen=true; done < <(jq -r '.[]' <<< "$alts")
          $seen || jq -r '.[0]' <<< "$alts"
        done)
    if [ -z "$new_markers" ]; then
      echo "Already tracked in #$existing: $title"; continue
    fi
    printf '%s\n\n%s\n%s\n' "$body" "$pr_lines" "$new_markers" > "$TMP/body.md"
    printf 'New source PR(s) for this item:\n\n%s\n\n%s\n' "$pr_lines" "$evidence" > "$TMP/comment.md"
    remember_issue "$existing" "$TMP/body.md"
    if [ "$DRY_RUN" = "true" ]; then
      preview "### Would update #$existing: $title" "" "$(cat "$TMP/comment.md")" ""
    else
      gh issue edit "$existing" --repo "$REPO" --body-file "$TMP/body.md" > /dev/null
      gh issue comment "$existing" --repo "$REPO" --body-file "$TMP/comment.md" > /dev/null
      SLACK_LINES+=("• *${title}* (updated): https://github.com/${REPO}/issues/${existing}")
    fi
    continue
  fi

  {
    echo "$evidence"; echo
    echo "**Source PRs**"; echo "$pr_lines"; echo
    echo "**Target version:** $version"
    [ "$breaking" = "true" ] && { echo; echo "**Possible breaking change.**"; }
    echo; echo "$markers"
    if [ -n "$extra" ]; then echo "$extra"; fi
  } > "$TMP/body.md"
  if [ "$DRY_RUN" = "true" ]; then
    remember_issue 0 "$TMP/body.md"
    preview "### Would create: $title" "" "$(cat "$TMP/body.md")" ""
  else
    args=(--repo "$REPO" --title "$title" --body-file "$TMP/body.md")
    [ "$breaking" = "true" ] && args+=(--label "breaking-change")
    mapfile -t aa < <(assign_args)
    url=$(gh issue create "${args[@]}" "${aa[@]}")
    remember_issue "${url##*/}" "$TMP/body.md"
    echo "Created $url"
    SLACK_LINES+=("• *${title}*: ${url}")
  fi
done < <(jq -c '.confirmed_items[]' "$SUMMARY")

# ---- 2. Major: completeness comments (targets verified by an earlier step)
if [ "$MODE" = "major" ]; then
  while read -r check; do
    num=$(jq -r .issue_number <<< "$check")
    jq -r '"**Completeness check: \(.classification)**\n\n\(.details)\n" +
      (if .classification == "COMPLETE" then "Ready to draft now." else "" end)' <<< "$check" > "$TMP/cc.md"
    if [ "$DRY_RUN" = "true" ]; then
      preview "### Would comment on #$num" "" "$(cat "$TMP/cc.md")" ""
    else
      gh issue comment "$num" --repo "$REPO" --body-file "$TMP/cc.md" > /dev/null
    fi
  done < <(jq -c '.completeness_checks[]?' "$SUMMARY")
fi

# ---- 3. Digest (every run) -----------------------------------------------
jq -r --arg mode "$MODE" '
  "**Scan digest**\n",
  "| Repo | PRs scanned | Prefiltered out |", "|---|---|---|",
  (. as $s | $s.scanned | to_entries[] | "| \(.key) | \(.value) | \($s.prefiltered_out[.key] // 0) |"),
  "",
  (if $mode == "major" then "Excluded as minor-bound: \(.excluded_as_minor.backport_found) backported, \(.excluded_as_minor.bugfix_type) bug fixes.\n" else empty end),
  "Candidates reviewed: \(.filtered_count). Prefiltered PRs stay listed to the model in its index; \(.promoted_from_index // 0) promoted to a full review.",
  "Confirmed \(.verified_counts.confirmed) · ruled out \(.verified_counts.ruled_out) · needs a look \(.verified_counts.needs_a_look) · held \(.verified_counts.held)",
  "",
  (if (.reviewed_items | map(select(.status != "ruled_out")) | length) > 0 then
     "**Needs a look / held**", (.reviewed_items[] | select(.status != "ruled_out") | "- \(.status): \(.source_prs | map("\(.repo)#\(.number)") | join(", ")): \(.reason)")
   else empty end),
  (if $mode == "major" and ((.completeness_checks // []) | length) > 0 then
     "", "**Completeness**", (.completeness_checks[] | "- #\(.issue_number): \(.classification)") else empty end)
' "$SUMMARY" > "$TMP/digest.md"

if [ "$DRY_RUN" = "true" ]; then
  preview "### Digest comment" "" "$(cat "$TMP/digest.md")"
else
  digest=$(gh issue list --repo "$REPO" --state open --limit 50 --search "\"$DIGEST_TITLE\" in:title" --json number,title \
             | jq -r --arg t "$DIGEST_TITLE" '[.[] | select(.title == $t)] | first | .number // empty')
  if [ -z "$digest" ]; then
    mapfile -t aa < <(assign_args)
    digest=$(gh issue create --repo "$REPO" --title "$DIGEST_TITLE" \
               --body "Running scan digest for the ${LABEL_TITLE} Release Watcher. One comment per run." "${aa[@]}" | grep -oE '[0-9]+$')
  fi
  gh issue comment "$digest" --repo "$REPO" --body-file "$TMP/digest.md" > /dev/null
fi

# ---- 4. Slack text (live runs with writes only) --------------------------
if [ "$DRY_RUN" != "true" ] && [ "${#SLACK_LINES[@]}" -gt 0 ]; then
  { echo "*${LABEL_TITLE} Release Watcher*: ${#SLACK_LINES[@]} doc need(s) tracked"; printf '%s\n' "${SLACK_LINES[@]}"; } > "$SLACK_FILE"
fi

if [ "$DRY_RUN" = "true" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "## ${LABEL_TITLE} Release Watcher -- dry-run preview"; echo; cat "$PREVIEW"; } >> "$GITHUB_STEP_SUMMARY"
fi
[ "$DRY_RUN" = "true" ] && cat "$PREVIEW"
exit 0
