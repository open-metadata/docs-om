#!/usr/bin/env python3
"""Sanitize raw PR discussion/comment text before an AI review reads it.

The doc-review workflows fetch PR discussion and inline review comments
themselves (`gh pr view --comments`, `gh api .../pulls/<n>/comments`) rather
than through the pinned claude-code-action's own context builder, so that
text never passes through the action's built-in sanitizeContent()/
redactSecrets() (src/github/utils/sanitizer.ts upstream). This script mirrors
that filtering -- stripping invisible/bidi/control characters, hidden
markdown/HTML attributes that can carry hidden instructions, and common
credential formats -- so the effect is equivalent even though the fetch path
is different.

Usage: sanitize-review-context.py <file> [<file> ...]
Each file is sanitized and rewritten in place.
"""

import re
import sys

ZERO_WIDTH = re.compile("[\u200B\u200C\u200D\uFEFF]")
CONTROL = re.compile("[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]")
SOFT_HYPHEN = re.compile("\u00AD")
BIDI_OVERRIDE = re.compile("[\u202A-\u202E\u2066-\u2069]")
HTML_COMMENT = re.compile(r"<!--[\s\S]*?-->")

MD_IMAGE_ALT = re.compile(r"!\[[^\]]*\]\(")
MD_IMAGE_ALT_REF = re.compile(r"!\[[^\]]*\](\[[^\]]*\])")
MD_LINK_TITLE_DQ = re.compile(r'(\[[^\]]*\]\([^)]+)\s+"[^"]*"')
MD_LINK_TITLE_SQ = re.compile(r"(\[[^\]]*\]\([^)]+)\s+'[^']*'")

HIDDEN_ATTRS = re.compile(
    r"""\s(?:alt|title|aria-label|data-[a-zA-Z0-9-]+|placeholder)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)""",
    re.IGNORECASE,
)

SECRET_PATTERNS = [
    re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"),
    re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    re.compile(r"xox[abpsr]-[A-Za-z0-9-]{10,}"),
    re.compile(
        r"eyJ[A-Za-z0-9_-]{10,2000}\.eyJ[A-Za-z0-9_-]{10,4000}\.[A-Za-z0-9_-]{10,2000}\b"
    ),
    re.compile(r"ghp_[A-Za-z0-9]{36}\b"),
    re.compile(r"gho_[A-Za-z0-9]{36}\b"),
    re.compile(r"ghu_[A-Za-z0-9]{36}\b"),
    re.compile(r"ghs_[A-Za-z0-9]{36}\b"),
    re.compile(r"ghr_[A-Za-z0-9]{36}\b"),
    re.compile(r"github_pat_[A-Za-z0-9_]{11,221}\b"),
]


def sanitize(text: str) -> str:
    text = ZERO_WIDTH.sub("", text)
    text = CONTROL.sub("", text)
    text = SOFT_HYPHEN.sub("", text)
    text = BIDI_OVERRIDE.sub("", text)
    text = HTML_COMMENT.sub("", text)
    text = MD_IMAGE_ALT_REF.sub(r"![]\1", text)
    text = MD_IMAGE_ALT.sub("![](", text)
    text = MD_LINK_TITLE_DQ.sub(r"\1", text)
    text = MD_LINK_TITLE_SQ.sub(r"\1", text)
    text = HIDDEN_ATTRS.sub("", text)
    for pattern in SECRET_PATTERNS:
        text = pattern.sub("[REDACTED]", text)
    return text


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: sanitize-review-context.py <file> [<file> ...]", file=sys.stderr)
        return 1
    for path in argv:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        with open(path, "w", encoding="utf-8") as f:
            f.write(sanitize(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
