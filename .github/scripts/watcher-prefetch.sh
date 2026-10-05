#!/usr/bin/env bash
# Deterministic prefetch for the Minor/Major Release Watchers.
#
# Everything a model used to do turn by turn with `gh` (listing PRs,
# dropping noise, matching backports, reading diffs, grepping the docs)
# runs here in plain bash/jq instead. The scan session gets an index of
# every PR, trimmed views of the candidates, and the complete body and diff
# of every PR on disk, so nothing is lost, only ordered. Source repos are
# still read only through gh-source-read.sh, so the read-only token keeps
# its allowlist. Nothing this script writes is trusted as instructions:
# PR text stays data and is handed to the model inside fenced blocks.
#
# Usage:
#   watcher-prefetch.sh select <minor|major>   list, filter, classify -> $OUT/candidates.json
#   watcher-prefetch.sh bundle                 views, full files, chunks -> $OUT/pr/, $OUT/chunk-*/
#   watcher-prefetch.sh completeness           major Part B           -> $OUT/completeness.json
#
# Env: OUT, LOOKBACK, MINOR_RELEASE_BRANCH, SOURCE_REPOS (comma-separated),
#      RELEASE_WATCHER_READ_TOKEN, GH_TOKEN (this repo, completeness only),
#      GITHUB_REPOSITORY.
# Per-repo settings (defaults are docs-collate's):
#   SOURCE_READER          command that runs `gh pr|issue ...` against the
#                          source repos (default: gh-source-read.sh, the
#                          read-only-token allowlist wrapper; docs-om reads
#                          its one public source repo with plain `gh`).
#   DOCS_DIRS              space-separated dirs the doc hints grep (default ".").
#   DOCS_EXCLUDE_DIRS      dir names the doc hints skip.
#   MARKER_STYLE           "repo" (pr-<repo>#<n>, default) or "number" (pr-<n>).
#   DEDUP_PREFIXES         marker prefixes that count as already tracked
#                          (default "<mode>-watcher").
#   TRUSTED_AUTHOR_RE      issue authors whose markers count (default github-actions).
#   BACKPORT_NEEDS_TRACKING=1  major only: a backported PR is excluded only
#                          once this repo already tracks it or its backport;
#                          otherwise it stays a candidate (docs-om's rule).
set -euo pipefail

OUT="${OUT:?OUT is required}"
SRC="${SOURCE_READER:-bash $(dirname "$0")/gh-source-read.sh}"
export SRC
DOCS_DIRS="${DOCS_DIRS:-.}"
DOCS_EXCLUDE_DIRS="${DOCS_EXCLUDE_DIRS:-docs-om node_modules .git}"
MARKER_STYLE="${MARKER_STYLE:-repo}"
TRUSTED_AUTHOR_RE="${TRUSTED_AUTHOR_RE:-github-actions}"
BACKPORT_NEEDS_TRACKING="${BACKPORT_NEEDS_TRACKING:-0}"
LIST_LIMIT="${LIST_LIMIT:-1000}"
DIFF_CAP_BYTES="${DIFF_CAP_BYTES:-9000}"
BODY_CAP_CHARS="${BODY_CAP_CHARS:-2000}"
# Keep each bundle under the Read tool's per-call token limit, so the
# model never has to re-read a bundle in pieces (paid for twice).
BUNDLE_MAX_BYTES="${BUNDLE_MAX_BYTES:-40000}"
# Candidate views per verify session; larger batches get more sessions.
CHUNK_MAX_BYTES="${CHUNK_MAX_BYTES:-160000}"
mkdir -p "$OUT/raw" "$OUT/diffs"

# Paths that never carry a doc need on their own. A PR touching only these
# is listed in the index as skipped (not dropped); their hunks are left out
# of the trimmed views but stay in the full diffs.
NOISE_PATH='^(skills|\.claude|\.cursor)/|(^|/)(CLAUDE|AGENTS)\.md$|(^|/)(tests?|e2e|playwright|cypress|__tests__|__mocks__|fixtures?)/|\.(test|spec)\.[jt]sx?$|_test\.(py|go)$|(^|/)test_[^/]+\.py$|(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|poetry\.lock|uv\.lock)$|\.lock$|\.snap$|\.(svg|png|jpe?g|gif|webp|ico|less|s?css)$|^\.github/|/locale/languages/(?!en-us)'
# Titles that are never user-facing (conventional-commit noise, test churn).
NOISE_TITLE='^(test|tests|ci|chore|build|style|refactor|docs|perf)(\([^)]*\))?!?:|^revert|playwright|flaky|dark (theme|mode)|co-author'

repo_name() { echo "${1#*/}"; }
PRIMARY_REPO=$(repo_name "${SOURCE_REPOS%%,*}")

# jq: hidden watcher markers in an issue body -> [{repo, number}], for the
# given prefixes regex, in either marker style.
MARKER_JQ='def markers($pfx): [.body // "" | scan("<!-- (?:" + $pfx + "):pr-(?:([A-Za-z0-9_.-]+)#)?([0-9]+) -->")
  | {repo: (.[0] // $primary), number: (.[1] | tonumber)}] | unique;'

# Large `pr list` pages (bodies + files) sometimes fail mid-response on
# GitHub's side; retry with backoff and fail the step only if all tries do.
src_to() {
  local out="$1"; shift
  local try
  for try in 1 2 3; do
    if $SRC "$@" > "$out.tmp" && jq -e . "$out.tmp" > /dev/null 2>&1; then
      mv "$out.tmp" "$out"; return 0
    fi
    echo "gh-source-read.sh $1 $2 failed (attempt $try/3); retrying" >&2
    sleep $((try * 10))
  done
  rm -f "$out.tmp"; return 1
}

# Exhaustive merged-PR listing. `gh pr list` stops at --limit and GitHub
# search never returns more than 1,000 results, so a full page is treated
# as cut off: the range is split in half until every part fits, and the
# step fails if a single day still does not.
list_merged() {
  local repo="$1" base="$2" out="$3"
  src_to "$out" pr list --repo "$repo" --state merged --base "$base" \
    --search "merged:>=$LOOKBACK" \
    --json number,title,url,body,labels,mergedAt,files,author \
    --limit "$LIST_LIMIT"
  [ "$(jq length "$out")" -lt "$LIST_LIMIT" ] && return 0
  echo "$repo: $LIST_LIMIT PRs since $LOOKBACK (cut off); splitting the range" >&2
  rm -f "$out".part-*
  split_range "$repo" "$base" "$LOOKBACK" "$(date -u +%Y-%m-%d)" "$out"
  jq -s 'add | unique_by(.number)' "$out".part-* > "$out"
  rm -f "$out".part-*
}
split_range() {
  local repo="$1" base="$2" from="$3" to="$4" out="$5" part
  part="$out.part-$from-$to"
  src_to "$part" pr list --repo "$repo" --state merged --base "$base" \
    --search "merged:$from..$to" \
    --json number,title,url,body,labels,mergedAt,files,author \
    --limit "$LIST_LIMIT"
  [ "$(jq length "$part")" -lt "$LIST_LIMIT" ] && return 0
  if [ "$from" = "$to" ]; then
    echo "::error::$repo: $LIST_LIMIT PRs merged on $from alone; cannot list them exhaustively." >&2
    exit 1
  fi
  local days mid
  days=$(( ($(date -u -d "$to" +%s) - $(date -u -d "$from" +%s)) / 86400 ))
  mid=$(date -u -d "$from +$((days / 2)) days" +%Y-%m-%d)
  rm -f "$part"
  split_range "$repo" "$base" "$from" "$mid" "$out"
  split_range "$repo" "$base" "$(date -u -d "$mid +1 day" +%Y-%m-%d)" "$to" "$out"
}

# Major + BACKPORT_NEEDS_TRACKING: PR numbers this repo's issues already
# track (any DEDUP_PREFIXES marker, trusted authors only), per source repo.
tracked_numbers() {
  local pfx p
  pfx=$(tr ' ' '|' <<< "${DEDUP_PREFIXES:-major-watcher}")
  for p in ${DEDUP_PREFIXES:-major-watcher}; do
    gh issue list --repo "$GITHUB_REPOSITORY" --state all --limit 1000 \
      --search "$p in:body" --json number,body,author
  done | jq -s -c --arg pfx "$pfx" --arg primary "$PRIMARY_REPO" --arg authors "$TRUSTED_AUTHOR_RE" "$MARKER_JQ"'
    [.[][] | select(.author.login // "" | test($authors)) | markers($pfx)[]] | unique' > "$OUT/raw/tracked-prs.json"
}

select_cmd() {
  local mode="$1" base
  case "$mode" in
    minor) base="$MINOR_RELEASE_BRANCH" ;;
    major) base="main" ;;
    *) echo "unknown mode '$mode'" >&2; exit 1 ;;
  esac

  local CLASSIFIED=()
  IFS=',' read -ra REPOS <<< "$SOURCE_REPOS"
  local needtrack=false
  if [ "$mode" = "major" ] && [ "$BACKPORT_NEEDS_TRACKING" = "1" ]; then
    needtrack=true; tracked_numbers
  fi
  for repo in "${REPOS[@]}"; do
    local name; name=$(repo_name "$repo")
    CLASSIFIED+=("$OUT/raw/$name.classified.json")
    list_merged "$repo" "$base" "$OUT/raw/$name.json"

    # Major only: every PR number referenced from the minor branch counts
    # as backported (title "Backport #N", body "cherry-pick of #N", ...).
    local refs='[]' bp='{}' tracked='[]'
    if [ "$mode" = "major" ]; then
      local since_bp; since_bp=$(date -u -d "$LOOKBACK -60 days" +%Y-%m-%d)
      src_to "$OUT/raw/$name-minor.json" pr list --repo "$repo" --state all --base "$MINOR_RELEASE_BRANCH" \
        --search "created:>=$since_bp" --json "$($needtrack && echo number,title,body || echo title,body)" --limit 1000
      refs=$(jq -c '[.[] | (.title + " " + (.body // "")) | scan("#([0-9]+)") | .[0] | tonumber] | unique' \
               "$OUT/raw/$name-minor.json")
      if $needtrack; then
        # Referenced PR number -> the minor-branch PRs (backports) naming it.
        bp=$(jq -c 'reduce (.[] | .number as $m | (.title + " " + (.body // "")) | scan("#([0-9]+)") | {k: .[0], m: $m}) as $e
                      ({}; .[$e.k] = ((.[$e.k] // []) + [$e.m] | unique))' "$OUT/raw/$name-minor.json")
        tracked=$(jq -c --arg r "$name" '[.[] | select(.repo == $r) | .number]' "$OUT/raw/tracked-prs.json")
      fi
    fi

    jq -c --arg repo "$name" --arg mode "$mode" --argjson refs "$refs" --arg ts "${LOOKBACK_TS:-}" \
      --argjson needtrack "$needtrack" --argjson bp "$bp" --argjson tracked "$tracked" \
      --arg np "$NOISE_PATH" --arg nt "$NOISE_TITLE" --argjson bodycap "$BODY_CAP_CHARS" '
      # Only dependency bots: app/gh-bot-collate authors real backports.
      def is_bot: (.author.login // "" | test("dependabot|renovate"; "i"));
      # Strip HTML comments, unchecked template boxes, tool footers, and
      # blank-line runs: they cost tokens and carry no signal.
      def body_clean: (.body // "" | gsub("<!--[\\s\\S]*?-->"; "") | gsub("\r"; "")
        | gsub("(?m)^\\s*- \\[ \\][^\n]*\n?"; "") | gsub("(?m)^.*Generated with \\[Claude Code\\].*\n?"; "")
        | gsub("\n{3,}"; "\n\n"));
      def checked($re): body_clean | test("- \\[[xX]\\] *(" + $re + ")"; "i");
      def breaking: ([.labels[].name] | any(test("breaking|backward-incompatible"; "i")))
                    or checked("Breaking");
      def bugfix_only:
        if (body_clean | test("Type of change"; "i")) then
          checked("Bug ?fix") and (checked("New feature|Improvement|Breaking|Documentation") | not)
        else (.title | test("^(fix|hotfix|bugfix)(\\([^)]*\\))?!?:"; "i")) end;
      def ref($kw): [body_clean | scan("(?i)(?:" + $kw + ")\\s+(?:open-metadata/(OpenMetadata|openmetadata-collate|ai-platform))?#([0-9]+)")
                     | {repo: (.[0] // $repo), number: (.[1] | tonumber)}] | first // null;
      {repo: $repo, items: [ .[] | select($ts == "" or .mergedAt >= $ts) | . as $p
        | ($p.files | map(.path) | map(select(test($np) | not))) as $real
        | {repo: $repo, number, url, title, mergedAt,
           labels: [.labels[].name], files: $real,
           body: (body_clean | .[0:$bodycap]),
           body_full: body_clean,
           # Verification disclaimers can sit past the body cap; keep them.
           verification_notes: [body_clean | split("\n")[]
             | select(test("(could ?n.t|cannot|can.t|unable to|did ?n.t|not (been )?)(run|test|build|verif)|untested|unverified|no (python )?venv|without (running|testing)"; "i"))
             | .[0:240]][0:5],
           breaking: breaking,
           tracking_issue: ref("fixes|closes|resolves|part of|relates to|tracking"),
           original_pr: ref("backport(?: of)?|cherry[- ]pick(?: of)?"),
           drop: (if is_bot then "bot"
                  elif (.title | test($nt; "i")) and (breaking | not) then "noise_title"
                  elif ($real | length) == 0 then "noise_paths"
                  elif $mode == "major" and ($refs | index($p.number)) then
                    # docs-om: a backport only settles the PR once this repo
                    # tracks it (or its backport); until then it is reviewed.
                    (if $needtrack and (([$p.number] + ($bp[$p.number | tostring] // []))
                                        | any(. as $x | $tracked | index($x)) | not)
                     then null else "backport_found" end)
                  elif $mode == "major" and bugfix_only and (breaking | not) then "bugfix_type"
                  else null end)}
           + (if $needtrack then {backport_prs: ($bp[$p.number | tostring] // [])} else {} end) ]}' \
      "$OUT/raw/$name.json" > "$OUT/raw/$name.classified.json"
  done

  # Merge per-repo results from files (too large for --argjson).
  jq -s '
      (map({(.repo): (.items | length)}) | add // {}) as $scanned
      | (map({(.repo): (.items | map(select(.drop == "bot" or .drop == "noise_title" or .drop == "noise_paths")) | length)}) | add // {}) as $pre
      | map(.items) | add // [] | {
          scanned: $scanned,
          prefiltered_out: $pre,
          excluded_as_minor: {
            backport_found: (map(select(.drop == "backport_found")) | length),
            bugfix_type: (map(select(.drop == "bugfix_type")) | length)
          },
          candidates: map(select(.drop == null) | del(.drop)),
          others: map(select(.drop != null))
        }' "${CLASSIFIED[@]}" > "$OUT/candidates.json"

  local n; n=$(jq '.candidates | length' "$OUT/candidates.json")
  echo "candidate_count=$n" >> "${GITHUB_OUTPUT:-/dev/null}"
  echo "Scanned $(jq -c .scanned "$OUT/candidates.json"); prefiltered out $(jq -c .prefiltered_out "$OUT/candidates.json"); excluded as minor $(jq -c .excluded_as_minor "$OUT/candidates.json"); candidates: $n"
}

# Doc-coverage hints: names a doc page would mention (connector, new schema
# properties), grepped in this repo's docs so the model confirms instead of
# searching 15 MB of MDX itself.
EXCLUDE_ARGS=()
for d in $DOCS_EXCLUDE_DIRS; do EXCLUDE_ARGS+=("--exclude-dir=$d"); done
doc_hints() {
  local diff="$1" files="$2" terms
  terms=$( {
      grep -oE 'ingestion/source/[a-z]+/[a-zA-Z0-9]+' <<< "$files" | awk -F/ '{print $NF}' || true
      grep -oE 'connections/[a-zA-Z]+/[a-zA-Z0-9]+Connection\.json' <<< "$files" | sed -E 's#.*/##; s/Connection\.json//' || true
      # Property keys anywhere in changed JSON hunks (context too:
      # a changed "minimum" sits under an unchanged property name).
      # No {n,m} intervals: mawk (Ubuntu's default awk) does not support them.
      awk '/^=== /{json = ($2 ~ /\.json$/)} json && /^[ +-][[:space:]]*"[a-zA-Z][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]*"[[:space:]]*:[[:space:]]*\{/' "$diff" \
        | sed -E 's/^[ +-][[:space:]]*"([^"]+)".*/\1/' || true
      # Schema "title" values in changed JSON hunks: the property key itself
      # often sits outside the hunk ("minimum" added under "Profile Sample").
      awk '/^=== /{json = ($2 ~ /\.json$/)} json && /^[ +-][[:space:]]*"title"[[:space:]]*:[[:space:]]*"[^"][^"][^"][^"]/' "$diff" \
        | sed -E 's/^[ +-][[:space:]]*"title"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true
      # Env-var style settings added to config files.
      grep -oE '^\+.*\$\{[A-Z][A-Z0-9_]{6,}' "$diff" | grep -oE '[A-Z][A-Z0-9_]{6,}$' || true
    } | { grep -vxiE 'type|properties|items|default|description|title|definitions|common|utils|base' || true; } \
      | sort -u | head -10 || true)
  [ -z "$terms" ] && { echo "doc hints: none derived"; return; }
  echo "doc hints (term -> existing docs pages):"
  while read -r t; do
    local hits
    # shellcheck disable=SC2086 # DOCS_DIRS is a space-separated list.
    hits=$(grep -rliF --include='*.mdx' "${EXCLUDE_ARGS[@]}" -- "$t" $DOCS_DIRS 2>/dev/null \
             | sed 's#^\./##' | head -3 | paste -sd, - || true)
    echo "- $t -> ${hits:-no docs match}"
  done <<< "$terms"
}

shorten_paths() {
  # Common path prefixes, abbreviated (legend in scan-system-prompt.md).
  sed -E \
    -e 's#openmetadata-ui/src/main/resources/ui/src/#om-ui/#g' \
    -e 's#collate-ui/src/main/resources/ui/src/#collate-ui/#g' \
    -e 's#openmetadata-service/src/main/java/org/openmetadata/service/#om-service/#g' \
    -e 's#openmetadata-spec/src/main/resources/json/schema/#om-schema/#g' \
    -e 's#collate-service/src/main/resources/json/schema/#collate-schema/#g' \
    -e 's#ingestion/src/metadata/ingestion/source/#ingestion-source/#g'
}

# Lossless by construction: every scanned PR is listed in index.md, every
# candidate gets a trimmed review view, and every PR's complete body and
# untrimmed diff are on disk for the model to Read whenever a trimmed view
# is not enough. Trimming only decides what is shown first, never what is
# reachable.
bundle_cmd() {
  mkdir -p "$OUT/pr"
  jq -c '.candidates + .others | .[]' "$OUT/candidates.json" > "$OUT/all.jsonl"

  # Fetch every PR's diff once, in parallel.
  jq -r '"\(.repo) \(.number)"' "$OUT/all.jsonl" \
    | xargs -P 8 -L 1 bash -c 'for t in 1 2 3; do $SRC pr diff "$2" --repo "open-metadata/$1" > "'"$OUT"'/pr/$1-$2.diff" 2>/dev/null && break; sleep $((t * 5)); done' _
  while read -r c; do
    jq -r '.body_full' <<< "$c" > "$OUT/pr/$(jq -r '"\(.repo)-\(.number)"' <<< "$c").body.md"
  done < "$OUT/all.jsonl"

  rm -f "$OUT"/bundle-*.md "$OUT"/view-*.md
  while read -r c; do
    local repo number raw clean full
    repo=$(jq -r .repo <<< "$c"); number=$(jq -r .number <<< "$c")
    raw="$OUT/pr/$repo-$number.diff"; clean="$OUT/diffs/$repo-$number.diff"
    # Trimmed view: drop noise files' hunks and git plumbing lines (same
    # rules as NOISE_PATH; awk has no lookahead, so the non-English locale
    # check is split out), keep one context line, order and cap.
    awk '
      /^diff --git / { path=$4; sub(/^b\//, "", path); skip = (path ~ /^(skills|\.claude|\.cursor)\/|(^|\/)(CLAUDE|AGENTS)\.md$|(^|\/)(tests?|e2e|playwright|cypress|__tests__|__mocks__|fixtures?)\/|\.(test|spec)\.[jt]sx?$|_test\.(py|go)$|(^|\/)test_[^\/]+\.py$|lock(\.json|\.yaml)?$|\.snap$|\.(svg|png|jpe?g|gif|webp|ico|less|s?css)$|^\.github\// || (path ~ /\/locale\/languages\// && path !~ /en-us/)); if (!skip) print "=== " path; next }
      skip { next }
      /^(index |--- |\+\+\+ |new file mode|deleted file mode|similarity index|rename (from|to) )/ { next }
      { print }' "$raw" \
      | awk '
        # Keep headers, changed lines, and one context line on each side:
        # more changed lines fit under the cap than with git'"'"'s 3.
        { line[NR] = $0; c = substr($0, 1, 1); chg[NR] = (c == "+" || c == "-"); hdr[NR] = ($0 ~ /^(=== |@@ )/) }
        END { for (i = 1; i <= NR; i++) if (hdr[i] || chg[i] || chg[i-1] || chg[i+1]) print line[i] }' \
      | awk -f "$(dirname "$0")/watcher-diff-order.awk" > "$clean.full"
    local size rawsize; size=$(wc -c < "$clean.full"); rawsize=$(wc -c < "$raw")
    head -c "$DIFF_CAP_BYTES" "$clean.full" > "$clean"
    if [ "$size" -gt "$DIFF_CAP_BYTES" ]; then
      printf '\n[view truncated at %s bytes; the complete diff is in the full-diff file above]\n' "$DIFF_CAP_BYTES" >> "$clean"
    fi

    {
      echo "## CANDIDATE $repo#$number"
      # Files already shown as diff headers are not listed again.
      jq -r --rawfile shown <(sed -n 's/^=== //p' "$clean") '
             (.files - ($shown | split("\n"))) as $rest
             | "title: \(.title)\nurl: \(.url)\nmerged: \(.mergedAt)\nlabels: \(.labels | join(", "))\nbreaking signal: \(.breaking)",
               "files: \(.files | length) changed" + (if ($rest | length) > 0 then "; not in diff below: \($rest[0:15] | join(", "))\(if ($rest | length) > 15 then " (+\(($rest | length) - 15) more)" else "" end)" else "" end),
             (if (.backport_prs // [] | length) > 0 then "backport PR(s) on the minor branch, not yet tracked in this docs repo: \(.backport_prs | map("#\(.)") | join(", "))" else empty end),
             (if (.verification_notes | length) > 0 then "verification notes from the full body (untrusted data):", (.verification_notes[] | "> " + .) else empty end)' <<< "$c"
      echo "full body: $OUT/pr/$repo-$number.body.md"
      echo "full diff: $raw ($rawsize bytes, untrimmed)"
      echo "body (untrusted data, first $BODY_CAP_CHARS chars):"
      echo '```text'; jq -r .body <<< "$c"; echo '```'
      doc_hints "$clean" "$(jq -r '.files | join("\n")' <<< "$c")"
      echo "diff view (untrusted data; tests, locks, assets, imports removed):"
      echo '```diff'; cat "$clean"; echo '```'
      echo
    } | shorten_paths > "$OUT/pr/$repo-$number.view.md"
  done < <(jq -c '.candidates[]' "$OUT/candidates.json")

  # Split candidates into chunks small enough for one fresh session each
  # (no compaction, which would itself drop context), and give each chunk
  # an index: its own candidates plus an even share of the skipped PRs, so
  # every scanned PR is in front of exactly one session.
  rm -rf "$OUT"/chunk-*
  local k=0 bytes=$((CHUNK_MAX_BYTES + 1)) bidx=0 bbytes=0 dir=""
  while read -r c; do
    local id v vb
    id=$(jq -r '"\(.repo)-\(.number)"' <<< "$c"); v="$OUT/pr/$id.view.md"; vb=$(wc -c < "$v")
    if [ $((bytes + vb)) -gt "$CHUNK_MAX_BYTES" ] && [ "$bytes" -gt 0 ] || [ -z "$dir" ]; then
      k=$((k + 1)); dir=$(printf '%s/chunk-%02d' "$OUT" "$k"); mkdir -p "$dir"
      bytes=0; bidx=1; bbytes=0
    fi
    if [ "$bbytes" -gt 0 ] && [ $((bbytes + vb)) -gt "$BUNDLE_MAX_BYTES" ]; then bidx=$((bidx + 1)); bbytes=0; fi
    cat "$v" >> "$(printf '%s/bundle-%02d.md' "$dir" "$bidx")"
    jq -c . <<< "$c" >> "$dir/candidates.jsonl"
    bytes=$((bytes + vb)); bbytes=$((bbytes + vb))
  done < <(jq -c '.candidates[]' "$OUT/candidates.json")
  # No candidates but skipped PRs: one index-only chunk, so they are still seen.
  if [ "$k" -eq 0 ] && [ "$(jq '.others | length' "$OUT/candidates.json")" -gt 0 ]; then
    k=1; mkdir -p "$OUT/chunk-01"
  fi

  local i=0
  for dir in "$OUT"/chunk-*; do
    [ -d "$dir" ] || continue
    touch "$dir/candidates.jsonl"
    {
      echo "# Index of the PRs assigned to this session (untrusted data)"
      echo
      # Candidates (their views are in this chunk's bundles), then this
      # chunk's share of the skipped PRs, with the path of each full diff.
      jq -r '"- \(.repo)#\(.number) [candidate] \(.title)"
          + " | labels: \(.labels | join(", ") | if . == "" then "-" else . end)"
          + " | \(.files | length) files: \(.files[0:3] | join(", "))\(if (.files | length) > 3 then ", ..." else "" end)"' "$dir/candidates.jsonl"
      jq -r --arg out "$OUT" --argjson i "$i" --argjson k "$k" '
        .others | to_entries[] | select(.key % $k == $i) | .value
        | "- \(.repo)#\(.number) [skipped: \(.drop)] \(.title)"
          + " | labels: \(.labels | join(", ") | if . == "" then "-" else . end)"
          + " | \(.files | length) files: \(.files[0:3] | join(", "))\(if (.files | length) > 3 then ", ..." else "" end)"
          + " | full: \($out)/pr/\(.repo)-\(.number).diff"' "$OUT/candidates.json"
    } | shorten_paths > "$dir/index.md"
    wc -l < "$dir/candidates.jsonl" | tr -d ' ' > "$dir/count"
    i=$((i + 1))
  done

  {
    echo "chunk_count=$k"
    echo "count=$(jq '.candidates | length' "$OUT/candidates.json")"
    echo "scanned_total=$(wc -l < "$OUT/all.jsonl" | tr -d ' ')"
  } >> "${GITHUB_OUTPUT:-/dev/null}"
  echo "Views: $(jq '.candidates | length' "$OUT/candidates.json") candidates, $(cat "$OUT"/pr/*.view.md 2>/dev/null | wc -c | tr -d ' ') bytes in $k chunk(s); $(wc -l < "$OUT/all.jsonl" | tr -d ' ') PRs indexed"
}

# Major Part B, deterministic: re-check multi-PR features already tracked.
completeness_cmd() {
  local checks='[]'
  # Only issues this workflow filed: notify refuses any other target.
  gh issue list --repo "$GITHUB_REPOSITORY" --state open --limit 200 \
    --search "major-watcher in:body" --json number,body,author \
    | jq -c '[.[] | select(.author.login // "" | test("github-actions"))]' > "$OUT/raw/tracked.json"
  while read -r issue; do
    local num prs
    num=$(jq -r .number <<< "$issue")
    if [ "$MARKER_STYLE" = "number" ]; then
      prs=$(jq -c --arg r "$PRIMARY_REPO" '[.body | scan("<!-- major-watcher:pr-([0-9]+) -->") | {repo: $r, number: (.[0] | tonumber)}] | unique' <<< "$issue")
    else
      prs=$(jq -c '[.body | scan("<!-- major-watcher:pr-([A-Za-z0-9_.-]+)#([0-9]+) -->") | {repo: .[0], number: (.[1] | tonumber)}] | unique' <<< "$issue")
    fi
    [ "$(jq length <<< "$prs")" -lt 2 ] && continue

    local refs='[]' details="" errors=0
    while read -r pr; do
      local r n view
      r=$(jq -r .repo <<< "$pr"); n=$(jq -r .number <<< "$pr")
      if view=$($SRC pr view "$n" --repo "open-metadata/$r" --json body,state,url 2>/dev/null); then
        details+="- PR $r#$n ($(jq -r .state <<< "$view")): $(jq -r .url <<< "$view")"$'\n'
        refs=$(jq -c --argjson v "$view" --arg r "$r" '. + [$v.body // "" | scan("(?i)(?:fixes|closes|resolves|part of)\\s+#([0-9]+)") | {repo: $r, number: (.[0] | tonumber)}] | unique' <<< "$refs")
      else
        errors=$((errors + 1)); details+="- PR $r#$n: could not be read"$'\n'
      fi
    done < <(jq -c '.[]' <<< "$prs")

    local classification outstanding=0 open_issues=0
    if [ "$(jq length <<< "$refs")" -eq 0 ] || [ "$errors" -gt 0 ]; then
      classification="UNCLEAR"
      details+="No tracking issue could be resolved from the tracked PRs' bodies, or a PR could not be read."$'\n'
    else
      while read -r ref; do
        local r x istate prs_json
        r=$(jq -r .repo <<< "$ref"); x=$(jq -r .number <<< "$ref")
        istate=$($SRC issue view "$x" --repo "open-metadata/$r" --json state,url 2>/dev/null || echo '{"state":"UNKNOWN","url":""}')
        [ "$(jq -r .state <<< "$istate")" != "CLOSED" ] && open_issues=$((open_issues + 1))
        prs_json=$($SRC pr list --repo "open-metadata/$r" --state all --search "$x in:body" --json number,state,url,body --limit 100 2>/dev/null || echo '[]')
        local open_prs
        open_prs=$(jq --arg x "$x" '[.[] | select((.body // "") | test("#" + $x + "\\b")) | select(.state == "OPEN")] | length' <<< "$prs_json")
        outstanding=$((outstanding + open_prs))
        details+="- Tracking issue $r#$x: $(jq -r .state <<< "$istate") $(jq -r .url <<< "$istate"); open referencing PRs: $open_prs"$'\n'
      done < <(jq -c '.[]' <<< "$refs")
      if [ "$open_issues" -eq 0 ] && [ "$outstanding" -eq 0 ]; then
        classification="COMPLETE"
      else
        classification="INCOMPLETE"
        details+="Outstanding: $open_issues open tracking issue(s), $outstanding open PR(s)."$'\n'
      fi
    fi
    checks=$(jq -c --argjson n "$num" --argjson p "$prs" --arg c "$classification" --arg d "$details" \
      '. + [{issue_number: $n, tracked_prs: $p, classification: $c, details: $d}]' <<< "$checks")
  done < <(jq -c '.[]' "$OUT/raw/tracked.json")
  jq -n --argjson c "$checks" '$c' > "$OUT/completeness.json"
  echo "Completeness checks: $(jq length "$OUT/completeness.json")"
}

case "${1:-}" in
  select) select_cmd "${2:?mode required}" ;;
  bundle) bundle_cmd ;;
  completeness) completeness_cmd ;;
  *) echo "usage: watcher-prefetch.sh <select <mode>|bundle|completeness>" >&2; exit 1 ;;
esac
