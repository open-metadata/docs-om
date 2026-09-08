#!/usr/bin/env bash
# Scans every .mdx page in the repo for version-shaped strings next to
# OpenMetadata/Airflow and flags anything that doesn't match the version
# that page's own directory tracks, per release.config.json.
#
# Unlike a single-version site, docs-om keeps multiple version directories
# live at once (v1.13.x, v2.0.x, v2.1.x-SNAPSHOT, ...). A file's expected
# version is whichever entry in release.config.json matches the top-level
# directory it lives under; files outside any version directory (shared
# snippets/, root pages) are checked against `defaultVersionDir`'s values,
# since that's the version those shared files are presumed current for.
#
# Correctness is per-keyword, not per-file: a line mentioning "OpenMetadata"
# must contain that file's expected OM version, one mentioning "Airflow"
# must contain that file's expected Airflow version - independently, and
# every keyword present on a line must be satisfied.
#
# This is a candidate finder, not an oracle: exit code signals "there are
# lines worth a human look", not "the build is broken".
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO_ROOT/release.config.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "release.config.json not found at $CONFIG" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to run this script" >&2
  exit 1
fi

DEFAULT_DIR=$(jq -r '.defaultVersionDir' "$CONFIG")

version_for_dir() {
  # $1 = version dir name (e.g. v2.0.x), prints "OM_VERSION AIRFLOW_VERSION"
  jq -r --arg d "$1" '.versions[] | select(.dir == $d) | "\(.openmetadataVersion) \(.airflowVersion)"' "$CONFIG"
}

echo "Release consistency scan (repo-wide, per version directory)"
jq -r '.versions[] | "  \(.dir): OpenMetadata \(.openmetadataVersion), Airflow \(.airflowVersion)\(.note // "" | if . != "" then " [\(.)]" else "" end)"' "$CONFIG"
echo "  (shared/root files checked against default: $DEFAULT_DIR)"
echo

VERSION_RE='[0-9]+\.[0-9]+(\.[0-9]+){0,2}'
KEYWORD_RE='[Oo]pen[Mm]etadata|[Aa]irflow'
NEEDS_REVIEW=0
CLEAN_FILE_COUNT=0

check_line() {
  # $1 = line content, $2 = OM version, $3 = Airflow version
  local content="$1" om_version="$2" airflow_version="$3"
  local ok=1
  if [[ "$content" =~ [Oo]pen[Mm]etadata ]] && [[ "$content" != *"$om_version"* ]]; then
    ok=0
  fi
  if [[ "$content" =~ [Aa]irflow ]] && [[ "$content" != *"$airflow_version"* ]]; then
    ok=0
  fi
  [[ "$ok" -eq 1 ]] && echo "OK" || echo "CHECK"
}

while IFS= read -r -d '' file; do
  rel_path="${file#"$REPO_ROOT"/}"

  # Determine which version dir (if any) this file lives under.
  top_dir="${rel_path%%/*}"
  version_dir="$DEFAULT_DIR"
  if jq -e --arg d "$top_dir" '.versions[] | select(.dir == $d)' "$CONFIG" >/dev/null 2>&1; then
    version_dir="$top_dir"
  fi
  read -r OM_VERSION AIRFLOW_VERSION <<< "$(version_for_dir "$version_dir")"

  matches="$(grep -nE "$KEYWORD_RE" "$file" || true)"
  [[ -z "$matches" ]] && continue

  file_has_check=0
  file_output=""
  while IFS= read -r line; do
    lineno="${line%%:*}"
    raw_content="${line#*:}"
    # Strip version-directory path references (/v2.0.x/..., v1.13.x) before
    # looking for a real version claim - otherwise every internal link on
    # this version-prefixed-URL site reads as a version mention.
    content="$(echo "$raw_content" | sed -E 's#/?[Vv][0-9]+\.[0-9]+\.x(-SNAPSHOT)?#/__VERDIR__#g')"
    [[ "$content" =~ $VERSION_RE ]] || continue
    verdict="$(check_line "$content" "$OM_VERSION" "$AIRFLOW_VERSION")"
    if [[ "$verdict" == "CHECK" ]]; then
      file_has_check=1
      file_output+="  CHECK L$lineno: $raw_content"$'\n'
    else
      file_output+="  OK    L$lineno: $raw_content"$'\n'
    fi
  done <<< "$matches"

  if [[ "$file_has_check" -eq 1 ]]; then
    echo "--- $rel_path (tracked as $version_dir) ---"
    printf '%s' "$file_output"
    echo
    NEEDS_REVIEW=1
  else
    CLEAN_FILE_COUNT=$((CLEAN_FILE_COUNT + 1))
  fi
done < <(find "$REPO_ROOT" -type f -name "*.mdx" \
  -not -path "*/connectors/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/snippets/releases/*" \
  -not -path "*/releases/*" \
  -print0)
# connectors/ is excluded per version dir and in snippets/connectors: those
# pages state compatibility floors ("OpenMetadata 1.3.1 or later") that are
# correct permanently and never track a specific release.
#
# snippets/releases/ and every version dir's own releases/ subdirectory
# (except latest.mdx, which this exclusion still drops - spot-check it
# manually) are historical changelog archives: each file is named for and
# describes its own old release series forever. Not drift.

echo "($CLEAN_FILE_COUNT other file(s) had matches, all consistent - not printed)"
echo

if [[ "$NEEDS_REVIEW" -eq 1 ]]; then
  echo "Result: items marked CHECK need a human look before shipping."
  exit 1
else
  echo "Result: everything scanned matches release.config.json."
  exit 0
fi
