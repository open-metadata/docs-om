#!/usr/bin/env bash
# Lists every source PR that an existing issue in this repo already
# references, as "<repo>#<number>" lines (unique, sorted). Run on every
# watcher pass so dedup covers issues the watcher never wrote itself:
# manually created issues, older watcher issues, and any marker style.
#
# Recognised references, in the issue body:
#   - hidden markers in any style, including several PRs in one comment:
#       <!-- major-watcher:pr-123 -->            (number only: primary repo)
#       <!-- major-watcher:pr-Repo#123 -->
#       <!-- major-watcher:pr-1 major-watcher:pr-2 -->
#   - PR URLs: github.com/open-metadata/<source repo>/pull/<n>
#   - plain "<source repo>#<n>" text (for example "OpenMetadata#28042")
#
# Usage: watcher-issue-refs.sh <label>
# Env:   GH_TOKEN, GITHUB_REPOSITORY, PRIMARY_REPO (default OpenMetadata),
#        SOURCE_REPO_NAMES (default "OpenMetadata openmetadata-collate ai-platform").
# Only issues carrying <label> are read, so the pass stays bounded to the
# release being tracked; open and closed issues both count.
set -euo pipefail

LABEL="${1:?label}"
PRIMARY_REPO="${PRIMARY_REPO:-OpenMetadata}"
NAMES="${SOURCE_REPO_NAMES:-OpenMetadata openmetadata-collate ai-platform}"
ALT=$(tr ' ' '|' <<< "$NAMES")

gh issue list --repo "$GITHUB_REPOSITORY" --state all --label "$LABEL" --limit 1000 \
    --json body --jq '.[].body // ""' \
  | python3 -c '
import re, sys
primary, alt = sys.argv[1], sys.argv[2]
text = sys.stdin.read()
refs = set()
for m in re.finditer(r"-watcher:pr-(?:([A-Za-z0-9_.-]+)#)?([0-9]+)", text):
    refs.add((m.group(1) or primary, m.group(2)))
for m in re.finditer(r"github\.com/open-metadata/(" + alt + r")/pull/([0-9]+)", text):
    refs.add((m.group(1), m.group(2)))
for m in re.finditer(r"\b(" + alt + r")#([0-9]+)", text):
    refs.add((m.group(1), m.group(2)))
for r, n in sorted(refs, key=lambda x: (x[0], int(x[1]))):
    print(f"{r}#{n}")
' "$PRIMARY_REPO" "$ALT"
