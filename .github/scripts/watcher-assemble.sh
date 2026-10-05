#!/usr/bin/env bash
# Builds the watcher handoff summary.json from deterministic prefetch data
# plus the scan session's structured verdicts.
#
# The model only returns verdicts keyed by "<repo>#<number>". Everything
# else (URLs, counts, tracking/backport references, exclusion stats) comes
# from the prefetch files, so the model cannot invent a PR, mis-count, or
# point a later issue write at something it was never shown. Every
# candidate ends up with a verdict: one the model skipped (turn cap,
# omission) becomes needs_a_look instead of disappearing. Prefiltered PRs
# keep their prefilter outcome unless the model, which saw them in the
# index, gave them a verdict of its own.
#
# Usage: watcher-assemble.sh <minor|major> <target_version> <verdicts.json>
# Env:   OUT (prefetch dir). Writes $OUT/handoff/summary.json.
set -euo pipefail

MODE="${1:?mode}"; TARGET="${2:?target version}"; VERDICTS="${3:?verdicts file}"
OUT="${OUT:?OUT is required}"
mkdir -p "$OUT/handoff"

jq -e '.verdicts | type == "array"' "$VERDICTS" > /dev/null 2>&1 || echo '{"verdicts":[]}' > "$VERDICTS"
[ -s "$OUT/completeness.json" ] || echo '[]' > "$OUT/completeness.json"

jq -n --arg mode "$MODE" --arg target "$TARGET" \
  --slurpfile cand "$OUT/candidates.json" \
  --slurpfile v "$VERDICTS" \
  --slurpfile cc "$OUT/completeness.json" '
  # Model text ends up in issue bodies: no HTML comments (forged markers),
  # no live @mentions, nothing shaped like a credential.
  def clean: tostring | gsub("<!--|-->"; "")
    | gsub("sk-ant-[A-Za-z0-9_-]+|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"; "[redacted]")
    | gsub("@(?<u>[A-Za-z0-9-])"; "@\u200b\(.u)") | .[0:700];
  # An empty model reason never reaches an issue or the digest as a blank.
  def reason_of($e): ($e.reason | clean) | if test("\\S") then . else "No reason returned by the scan session; review manually." end;
  def id: "\(.repo)#\(.number)";
  (($cand[0].candidates + ($cand[0].others // [])) | map({key: id, value: .}) | from_entries) as $all
  | ($cand[0].candidates | map(id)) as $candidates
  | ($all | keys) as $known
  # Keep each PR in the first verdict entry that names it; ignore unknown ids.
  | (reduce ($v[0].verdicts[]) as $e ({seen: [], out: []};
        (([$e.prs[] | select(IN($known[]))] | unique) - .seen) as $new
        | if ($new | length) == 0 then . else
            .seen += $new | .out += [$e + {prs: $new}] end)) as $r
  | ($candidates - $r.seen) as $missing
  | ($r.out + ($missing | map({prs: [.], verdict: "needs_a_look",
        reason: "No verdict returned by the scan session (turn cap or omission); review manually.",
        suggested_title: "", breaking: false}))) as $entries
  | ($r.seen - $candidates) as $promoted
  | def src($e): $e.prs | map($all[.] | {repo, number, url});
  {
    scanned: $cand[0].scanned,
    prefiltered_out: $cand[0].prefiltered_out,
    promoted_from_index: ($promoted | length),
    filtered_count: ($candidates | length),
    verified_counts: {
      held: ($entries | map(select(.verdict == "held")) | length),
      ruled_out: ($entries | map(select(.verdict == "ruled_out")) | length),
      needs_a_look: ($entries | map(select(.verdict == "needs_a_look")) | length),
      confirmed: ($entries | map(select(.verdict == "confirmed")) | length)
    },
    confirmed_items: [ $entries[] | select(.verdict == "confirmed") | . as $e
      | (src($e)) as $s
      | {source_prs: $s,
         evidence: reason_of($e),
         target_version: $target,
         suggested_title: ((if ($e.suggested_title | test("\\S")) then $e.suggested_title else $all[$e.prs[0]].title end) | clean | .[0:120]),
         breaking: ($e.breaking or ($e.prs | any($all[.].breaking))),
         tracking_issue: ([$e.prs[] | $all[.].tracking_issue | select(. != null)] | first // null),
         original_pr: ([$e.prs[] | $all[.].original_pr | select(. != null)] | first // null)} ],
    reviewed_items: [ $entries[] | select(.verdict != "confirmed") | . as $e
        | {status: $e.verdict, source_prs: src($e), reason: reason_of($e)} ]
  }
  + (if $mode == "major" then {excluded_as_minor: $cand[0].excluded_as_minor, completeness_checks: $cc[0]} else {} end)
  ' > "$OUT/handoff/summary.json"

jq -c '{filtered_count, promoted_from_index, verified_counts}' "$OUT/handoff/summary.json"
