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
#        TRACKER_TITLE     tracker issue title (default "[<ver>] Documentation tracker")
#        TRACKER_MODE      "full" (default: the watcher owns the tracker body) or
#                          "block" (a hand-written tracker: only the section between
#                          the tracker-begin/tracker-end markers is rewritten)
#        SUB_TITLE_TEMPLATE sub-issue title, with {ver}, {area}, {title} (default "{title}")
#        TARGET_VERSION    major only: when set (and every confirmed item carries an
#                          area), items become sub-issues of the release tracker
#                          issue and its ledger table is updated (see release_flow below)
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
PREVIEW="$(mktemp)"; SLACK_LINES=(); DRY_LINES=()
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

# ---- 1a. Major release tracking: one tracker issue, sub-issues, ledger ----
# One tracker issue per release ("[2.1] Documentation tracker", label 2.1).
# Every confirmed item becomes a sub-issue of it. The tracker body is
# regenerated each run: a checklist of sub-issues grouped by area (ticked
# when the sub-issue is closed), then a table of every source PR filed so
# far. The scan job reads that table first and skips every PR in it, and
# this step also skips PRs already in the table or carrying a marker, so a
# PR is never filed twice. Humans edit the Status and Docs PR cells.
release_mode() {
  [ "$MODE" = "major" ] && [ -n "${TARGET_VERSION:-}" ] \
    && jq -e '(.confirmed_items | length == 0) or all(.confirmed_items[]; has("area"))' "$SUMMARY" > /dev/null
}

# The tracker may be created by this workflow or by a maintainer listed in
# NOTIFY_USERNAMES; nobody else's issue counts (public repos let anyone
# open an issue with the same title).
tracker_author_re() {
  local re="$TRUSTED_AUTHOR_RE" u
  for u in $(tr "," " " <<< "${NOTIFY_USERNAMES:-}"); do re="$re|^${u}\$"; done
  echo "$re"
}

LEDGER_ROWS="$TMP/ledger.tsv"   # pr<TAB>area<TAB>sub-issue<TAB>status<TAB>docs pr
NEW_ROWS="$TMP/new-rows.tsv"
NEW_TITLES="$TMP/new-titles.tsv" # dry run only: "(new) <area> title" lines

# True when the PR is in the ledger table or any existing release issue
# references it (see watcher-issue-refs.sh).
ledger_has() { cut -f1 "$LEDGER_ROWS" | grep -qxF -- "$1" || grep -qxF -- "$1" "$ISSUE_REFS"; }
ISSUE_REFS="$TMP/issue-refs.txt"

load_ledger_rows() {
  : > "$LEDGER_ROWS"; : > "$NEW_ROWS"; : > "$NEW_TITLES"
  bash "$(dirname "$0")/watcher-issue-refs.sh" "$TARGET_VERSION" > "$ISSUE_REFS" 2>/dev/null \
    || { echo "::warning::Could not read existing issues for dedup; relying on the ledger and markers only."; : > "$ISSUE_REFS"; }
  TRACKER_NUM=$(gh issue list --repo "$REPO" --state open --limit 50 \
      --search "\"$TRACKER_TITLE\" in:title" --json number,title,author \
    | jq -r --arg t "$TRACKER_TITLE" --arg a "$(tracker_author_re)" \
        '[.[] | select(.title == $t and (.author.login // "" | test($a)))] | first | .number // empty')
  [ -n "$TRACKER_NUM" ] || return 0
  gh issue view "$TRACKER_NUM" --repo "$REPO" --json body -q .body \
    | { grep -E '^\| [A-Za-z0-9_.-]+#[0-9]+ \|' || true; } \
    | awk -F'|' '{ for (i = 2; i <= 6; i++) { gsub(/^ +| +$/, "", $i) } print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 }' \
    > "$LEDGER_ROWS"
}

# Tracker body from the ledger rows: checklist per area, then the table.
write_tracker() {
  cat "$LEDGER_ROWS" "$NEW_ROWS" > "$TMP/all-rows.tsv"
  # Sub-issues linked to the tracker that no row names (filed manually, or
  # skipped as already referenced) still belong in the checklist. Their area
  # comes from the "**Area**: X" line this watcher writes, else "Other".
  if [ -n "$TRACKER_NUM" ]; then
    gh api "repos/${REPO}/issues/${TRACKER_NUM}/sub_issues?per_page=100" --jq '.[].number' 2>/dev/null \
      | while read -r n; do
          [ -n "$n" ] || continue
          if awk -F'\t' -v s="#$n" '$3 == s { f = 1 } END { exit !f }' "$TMP/all-rows.tsv"; then continue; fi
          info=$(gh issue view "$n" --repo "$REPO" --json title,body 2>/dev/null || echo '{}')
          area=$(jq -r '.body // ""' <<< "$info" | sed -n 's/^\*\*Area\*\*: //p' | head -1 | tr -d '|\r')
          # Hand-filed issues: "[2.1 Docs] <Area>: <Feature>" names the area.
          [ -n "$area" ] || area=$(jq -r '.title // ""' <<< "$info" | sed -nE 's/^\[[^]]*\] *([^:]+):.*/\1/p' | tr -d '|')
          printf '%s#%s\t%s\t#%s\ttracked\t\n' "${REPO#*/}" "$n" "${area:-Other}" "$n" >> "$TMP/all-rows.tsv"
        done
  fi
  {
    echo "Tracking issue for all documentation work on the ${TARGET_VERSION} release. Each item below is a sub-issue labeled \`${TARGET_VERSION}\`. The watcher adds new work here on every run."
    echo
    cut -f2 "$TMP/all-rows.tsv" | awk '!seen[$0]++' | while read -r area; do
      echo "## $area"; echo
      awk -F'\t' -v a="$area" '$2 == a && $3 != "-" { print $3 }' "$TMP/all-rows.tsv" | awk '!seen[$0]++' | while read -r sub; do
        n="${sub#\#}"
        if [ "$sub" = "(new)" ]; then continue; fi
        if info=$(gh issue view "$n" --repo "$REPO" --json state,title 2>/dev/null); then
          box=" "; [ "$(jq -r .state <<< "$info")" = "CLOSED" ] && box="x"
          echo "- [$box] #$n $(jq -r .title <<< "$info" | sed -E 's/^\[[^]]*\] *//')"
        else
          echo "- [ ] #$n"
        fi
      done
      awk -F'\t' -v a="$area" '$1 == "NEWTITLE" && $2 == a { print "- [ ] (new) " $3 }' "$NEW_TITLES"
      echo
    done
    echo "## Source PR ledger"; echo
    echo "Each run skips every PR listed here. Edit **Status** or **Docs PR** to record manual coverage; do not edit the PR column."
    echo
    echo "| PR | Area | Sub-issue | Status | Docs PR |"
    echo "|---|---|---|---|---|"
    awk -F'\t' '{ print "| " $1 " | " $2 " | " $3 " | " $4 " | " $5 " |" }' "$TMP/all-rows.tsv"
    echo
    echo "<!-- ${PREFIX}:tracker-${TARGET_VERSION} -->"
  } > "$TMP/tracker.md"
  if [ "${TRACKER_MODE:-full}" = "block" ]; then
    # Hand-written tracker: keep everything outside the managed block.
    local begin="<!-- ${PREFIX}:tracker-begin -->" end="<!-- ${PREFIX}:tracker-end -->"
    if [ -n "$TRACKER_NUM" ]; then
      gh issue view "$TRACKER_NUM" --repo "$REPO" --json body -q .body > "$TMP/tracker-old.md"
    else
      : > "$TMP/tracker-old.md"
    fi
    awk -v b="$begin" -v e="$end" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$TMP/tracker-old.md" \
      | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$TMP/tracker-keep.md"
    { cat "$TMP/tracker-keep.md"; echo; echo; echo "$begin"; sed '1,2d' "$TMP/tracker.md"; echo "$end"; } > "$TMP/tracker-block.md"
    mv "$TMP/tracker-block.md" "$TMP/tracker.md"
  fi
  if [ "$DRY_RUN" = "true" ]; then
    if [ -n "$TRACKER_NUM" ]; then verb="update #$TRACKER_NUM"; else verb="create"; fi
    preview "### Would $verb: $TRACKER_TITLE" "" "$(cat "$TMP/tracker.md")" ""
  elif [ -n "$TRACKER_NUM" ]; then
    gh issue edit "$TRACKER_NUM" --repo "$REPO" --body-file "$TMP/tracker.md" > /dev/null
  else
    mapfile -t aa < <(assign_args)
    gh issue create --repo "$REPO" --title "$TRACKER_TITLE" --body-file "$TMP/tracker.md" \
      --label "$TARGET_VERSION" "${aa[@]}" > /dev/null
  fi
}

# live runs: make sure the tracker exists before sub-issues link to it
ensure_tracker() {
  [ -n "$TRACKER_NUM" ] && return 0
  [ "$DRY_RUN" = "true" ] && return 0
  printf 'Tracking issue for the %s release. This body is filled in at the end of the run.\n\n<!-- %s:tracker-%s -->\n' \
    "$TARGET_VERSION" "$PREFIX" "$TARGET_VERSION" > "$TMP/tracker-stub.md"
  mapfile -t aa < <(assign_args)
  TRACKER_NUM=$(gh issue create --repo "$REPO" --title "$TRACKER_TITLE" --body-file "$TMP/tracker-stub.md" \
                  --label "$TARGET_VERSION" "${aa[@]}" | grep -oE '[0-9]+$')
  echo "Created tracker #$TRACKER_NUM" >&2
  SLACK_LINES+=("$(printf 'Tracker\thttps://github.com/%s/issues/%s' "$REPO" "$TRACKER_NUM")")
}

link_sub_issue() {
  local parent="$1" sub="$2" id
  if id=$(gh api "repos/${REPO}/issues/${sub}" --jq .id 2>/dev/null) \
     && gh api -X POST "repos/${REPO}/issues/${parent}/sub_issues" -F "sub_issue_id=${id}" > /dev/null 2>&1; then
    return 0
  fi
  # The checklist in the tracker body still lists it; only the sub-issues panel misses it.
  echo "::warning::Could not link #$sub as a sub-issue of #$parent; it is still listed in the tracker body."
}

release_flow() {
  TRACKER_TITLE="${TRACKER_TITLE:-[${TARGET_VERSION}] Documentation tracker}"
  load_ledger_rows
  while read -r item; do
    area=$(jq -r .area <<< "$item")
    title=$(jq -r .suggested_title <<< "$item")
    breaking=$(jq -r .breaking <<< "$item")
    tpl="${SUB_TITLE_TEMPLATE:-}"; [ -n "$tpl" ] || tpl='{title}'
    tpl="${tpl//\{ver\}/$TARGET_VERSION}"; tpl="${tpl//\{area\}/$area}"
    full_title="${tpl//\{title\}/$title}"
    # Source PRs not yet in the ledger and not carrying a marker anywhere.
    new_prs='[]'
    while read -r sp; do
      id=$(jq -r '"\(.repo)#\(.number)"' <<< "$sp")
      if ledger_has "$id"; then continue; fi
      m=$(jq -r --arg p "$PREFIX" --arg style "$MARKER_STYLE" "$MK"'mk($p; "pr"; .repo; .number)' <<< "$sp")
      legacy=$(find_issue_with "$m")
      if [ -n "$legacy" ]; then
        printf '%s\t%s\t#%s\ttracked\t\n' "$id" "$area" "$legacy" >> "$NEW_ROWS"
        continue
      fi
      new_prs=$(jq -c --argjson sp "$sp" '. + [$sp]' <<< "$new_prs")
    done < <(jq -c '.source_prs[]' <<< "$item")
    if [ "$(jq length <<< "$new_prs")" -eq 0 ]; then echo "Already tracked: $title"; continue; fi

    ensure_tracker
    pr_lines=$(jq -r '.[] | "- \(.repo)#\(.number): \(.url)"' <<< "$new_prs")
    markers=$(jq -r --arg p "$PREFIX" --arg style "$MARKER_STYLE" "$MK"'.[] | mk($p; "pr"; .repo; .number)' <<< "$new_prs")
    {
      jq -r .summary <<< "$item"; echo
      echo "**Area**: $area"; echo
      echo "**Source PRs**"; echo "$pr_lines"; echo
      echo "**Doc tasks**"
      if [ "$(jq '.checkboxes | length' <<< "$item")" -gt 0 ]; then
        jq -r '.checkboxes[] | "- [ ] " + .' <<< "$item"
      else
        echo "- [ ] Review the source PRs and decide what to document"
      fi
      echo
      [ -n "$TRACKER_NUM" ] && { echo "**Tracker**: #$TRACKER_NUM"; echo; }
      [ "$breaking" = "true" ] && { echo "**Possible breaking change.**"; echo; }
      echo "**Target version**: $TARGET_VERSION"; echo
      echo "$markers"
    } > "$TMP/body.md"

    if [ "$DRY_RUN" = "true" ]; then
      remember_issue 0 "$TMP/body.md"
      preview "### Would create sub-issue under $TRACKER_TITLE ($area): $full_title" "" "$(cat "$TMP/body.md")" ""
      printf 'NEWTITLE\t%s\t%s\n' "$area" "$title" >> "$NEW_TITLES"
      DRY_LINES+=("$(printf '[%s] %s\t' "$area" "$full_title")")
      sub="(new)"
    else
      args=(--repo "$REPO" --title "$full_title" --body-file "$TMP/body.md" --label "$TARGET_VERSION")
      [ "$breaking" = "true" ] && args+=(--label "breaking-change")
      mapfile -t aa < <(assign_args)
      url=$(gh issue create "${args[@]}" "${aa[@]}")
      sub="${url##*/}"
      remember_issue "$sub" "$TMP/body.md"
      link_sub_issue "$TRACKER_NUM" "$sub"
      echo "Created $url"
      SLACK_LINES+=("$(printf '[%s] %s\t%s' "$area" "$title" "$url")")
      sub="#$sub"
    fi
    jq -r --arg a "$area" --arg s "$sub" \
      '.[] | "\(.repo)#\(.number)\t\($a)\t\($s)\ttracked\t"' <<< "$new_prs" >> "$NEW_ROWS"
  done < <(jq -c '.confirmed_items[]' "$SUMMARY")
  # Refresh the tracker every run (also ticks boxes for closed sub-issues).
  [ -n "$TRACKER_NUM" ] || [ -s "$NEW_ROWS" ] && write_tracker
  return 0
}

# ---- 1. Confirmed items -> create or update tracking issues -------------
if release_mode; then
  release_flow
else
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
      SLACK_LINES+=("$(printf '%s (updated)\thttps://github.com/%s/issues/%s' "$title" "$REPO" "$existing")")
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
    DRY_LINES+=("$(printf '%s\t' "$title")")
  else
    args=(--repo "$REPO" --title "$title" --body-file "$TMP/body.md")
    [ "$breaking" = "true" ] && args+=(--label "breaking-change")
    mapfile -t aa < <(assign_args)
    url=$(gh issue create "${args[@]}" "${aa[@]}")
    remember_issue "${url##*/}" "$TMP/body.md"
    echo "Created $url"
    SLACK_LINES+=("$(printf '%s\t%s' "$title" "$url")")
  fi
done < <(jq -c '.confirmed_items[]' "$SUMMARY")
fi

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

# ---- 4. Report text for the Slack message (every run) --------------------
# watcher-slack-report.sh posts this file after the run finishes, with the
# pass or fail status. It lists what was created, or in a dry run what would be.
# Format: one summary line, then one "<issue name><TAB><url>" row per issue
# (the url is empty in a dry run); the report script turns rows into a table.
if [ "$DRY_RUN" = "true" ]; then
  if [ "${#DRY_LINES[@]}" -gt 0 ]; then
    { echo "Dry run, nothing was written. Would create ${#DRY_LINES[@]} issue(s):"; printf '%s\n' "${DRY_LINES[@]}"; } > "$SLACK_FILE"
  else
    echo "Dry run, nothing was written. No new issues would be created." > "$SLACK_FILE"
  fi
elif [ "${#SLACK_LINES[@]}" -gt 0 ]; then
  { echo "Issues created or updated (${#SLACK_LINES[@]}):"; printf '%s\n' "${SLACK_LINES[@]}"; } > "$SLACK_FILE"
else
  echo "No new issues created." > "$SLACK_FILE"
fi

if [ "$DRY_RUN" = "true" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "## ${LABEL_TITLE} Release Watcher -- dry-run preview"; echo; cat "$PREVIEW"; } >> "$GITHUB_STEP_SUMMARY"
fi
[ "$DRY_RUN" = "true" ] && cat "$PREVIEW"
exit 0
