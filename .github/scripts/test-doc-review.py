#!/usr/bin/env python3
"""Local regression checks; uses a mock Claude CLI, never the network."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact", SCRIPTS / "compact-review-diff.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def patch(path, content="new", line=1):
    return (
        f"diff --git a/{path} b/{path}\n"
        "index abcdef0..1234567 100644\n"
        f"--- a/{path}\n+++ b/{path}\n"
        f"@@ -{line},2 +{line},2 @@\n context\n-old\n+{content}\n"
    )


class ReviewTests(unittest.TestCase):
    def test_identical_versions_preserve_paths_and_lines(self):
        first = patch("v2.0.x/page.mdx")
        second = patch("v2.1.x-SNAPSHOT/page.mdx").replace("abcdef0..1234567", "ddddddd..eeeeeee")
        compact = MODULE.compact(first + second)
        self.assertEqual(compact.count("diff --git "), 1)
        self.assertIn("v2.0.x/page.mdx", compact)
        self.assertIn("v2.1.x-SNAPSHOT/page.mdx", compact)
        self.assertIn("@@ -1,2 +1,2 @@", compact)

    def test_distinct_context_content_or_locations_are_not_merged(self):
        first = patch("v2.0.x/page.mdx")
        for second in (
            patch("v2.1.x-SNAPSHOT/page.mdx", "different"),
            patch("v2.1.x-SNAPSHOT/page.mdx", line=20),
            patch("v2.1.x-SNAPSHOT/page.mdx").replace(" context", " other context"),
            patch("v2.0.x/other-page.mdx"),
            patch("v2.1.x-SNAPSHOT/page.md"),
        ):
            self.assertEqual(MODULE.compact(first + second), first + second)

    def test_collate_root_and_ai_versions(self):
        text = patch("deployment/page.mdx") + patch("ai-2-0/deployment/page.mdx")
        self.assertEqual(MODULE.compact(text).count("diff --git "), 1)

    def test_renames_additions_and_quoted_paths_pass_through(self):
        text = (
            'diff --git "a/a b.mdx" "b/a b.mdx"\n-old\n+new\n'
            "diff --git a/old.mdx b/new.mdx\nrename from old.mdx\nrename to new.mdx\n"
            "diff --git a/new.mdx b/new.mdx\n--- /dev/null\n+++ b/new.mdx\n@@ -0,0 +1 @@\n+new\n"
        )
        self.assertEqual(MODULE.compact(text), text)

    def run_review(self, discussion, chunked=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            context = root / "context"
            context.mkdir()
            captures = root / "captures"
            captures.mkdir()
            first = patch("v2.0.x/page.mdx", "new " * 150)
            second = patch("v2.1.x-SNAPSHOT/page.mdx", "new " * 150)
            (context / "pr-diff.patch").write_text(first + second + patch("other.mdx", "other " * 150))
            (context / "pr-review-discussion.json").write_text(json.dumps({"title": "Title", "body": "Description"}))
            # Automatic mode must work with no discussion files on disk.
            if discussion:
                (context / "pr-inline-review-comments.json").write_text('["INLINE_CANARY"]')
                (context / "pr-submitted-reviews.json").write_text('["REVIEW_CANARY"]')
            cli = root / "claude"
            cli.write_text(
                "#!" + sys.executable + "\n"
                "import json, os, pathlib, sys\n"
                "text = sys.stdin.read()\n"
                "pathlib.Path(os.environ['CAPTURES'], str(os.getpid()) + '.txt').write_text(text)\n"
                "report = '### Review Report\\n\\n**Content type**: Documentation\\n**Overall verdict**: PASS\\n**Reason**: No issues found\\n**Reviewed revision**: bbbbbbb\\n**Findings**: `Critical=0 Major=0 Minor=0`\\n\\n#### Issues Found\\n\\nNo issues found.'\n"
                "print(json.dumps({'result': report, 'is_error': False, 'num_turns': 1, 'duration_ms': 1}))\n"
            )
            cli.chmod(0o755)
            output = root / "report.md"
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                       CAPTURES=str(captures), CONTEXT_DIR=str(context),
                       POLICY_DIR=str(SCRIPTS.parent.parent / ".ai/doc-review"),
                       GITHUB_REPOSITORY="example/docs", PR_NUMBER="1",
                       BASE_SHA="a" * 40, HEAD_SHA="b" * 40, RUN_URL="https://example.com/run",
                       REVIEW_REUSE="0", REVIEW_INCREMENTAL="0", REVIEW_POST="0",
                       REVIEW_OUT=str(output), REVIEW_DISCUSSION=str(int(discussion)),
                       REVIEW_DEDUP="1", REVIEW_INLINE_MAX="100" if chunked else "300000",
                       REVIEW_CHUNK_MAX="1500", CLAUDE_CONFIG_DIR_OVERRIDE="inherit")
            subprocess.run(["bash", str(SCRIPTS / "doc-review-run.sh")], cwd=root, env=env,
                           check=True, capture_output=True, text=True)
            prompts = [file.read_text() for file in captures.iterdir()]
            self.assertGreater(len(prompts), 1 if chunked else 0)
            self.assertIn("Critical=0 Major=0 Minor=0", output.read_text())
            joined = "\n".join(prompts)
            self.assertEqual("comment(s) on this PR were excluded" in joined, discussion)
            self.assertIn("v2.0.x/page.mdx", joined)
            self.assertIn("v2.1.x-SNAPSHOT/page.mdx", joined)
            self.assertEqual("INLINE_CANARY" in joined, discussion)
            self.assertEqual("REVIEW_CANARY" in joined, discussion)
            if not chunked:
                self.assertEqual(joined.count("+new "), 1)

    def test_automatic_without_discussion_files(self):
        self.run_review(False)

    def test_manual_retains_discussion(self):
        self.run_review(True)

    def test_chunked_automatic_without_discussion_files(self):
        self.run_review(False, chunked=True)

    def test_chunked_repeated_findings_are_grouped_before_verdict(self):
        # The same Major correction found independently in four chunks is one
        # grouped finding, so it must remain NEEDS WORK rather than becoming a
        # four-Major FAIL. Every affected location must survive the merge.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            context = root / "context"
            context.mkdir()
            (context / "pr-diff.patch").write_text(
                "".join(patch(f"page-{number}.mdx", "new " * 300) for number in range(4)))
            (context / "pr-review-discussion.json").write_text(
                json.dumps({"title": "Title", "body": "Description"}))
            cli = root / "claude"
            cli.write_text(
                "#!" + sys.executable + "\n"
                "import json, re, sys\n"
                "text = sys.stdin.read()\n"
                "part = re.search(r'part (\\d+) of', text).group(1)\n"
                "report = f'''### Review Report\n\n**Content type**: Documentation\n"
                "**Overall verdict**: NEEDS WORK\n**Reason**: 1 Major issue\n"
                "**Reviewed revision**: bbbbbbb\n**Findings**: `Critical=0 Major=1 Minor=0`\n\n"
                "#### Issues Found\n\n| # | Guideline | Severity | Original text | Suggested change |\n"
                "|---|-----------|----------|---------------|-----------------|\n"
                "| 1 | Same rule | Major | \\\"bad\\\" (page-{part}.mdx:1) | Use good wording. |'''\n"
                "print(json.dumps({'result': report, 'is_error': False, 'num_turns': 1, 'duration_ms': 1}))\n"
            )
            cli.chmod(0o755)
            output = root / "report.md"
            env = dict(
                os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                CONTEXT_DIR=str(context), POLICY_DIR=str(SCRIPTS.parent.parent / ".ai/doc-review"),
                GITHUB_REPOSITORY="example/docs", PR_NUMBER="1", BASE_SHA="a" * 40,
                HEAD_SHA="b" * 40, RUN_URL="https://example.com/run", REVIEW_REUSE="0",
                REVIEW_INCREMENTAL="0", REVIEW_POST="0", REVIEW_OUT=str(output),
                REVIEW_DISCUSSION="0", REVIEW_DEDUP="0", REVIEW_INLINE_MAX="100",
                REVIEW_CHUNK_MAX="1500", CLAUDE_CONFIG_DIR_OVERRIDE="inherit",
            )
            subprocess.run(
                ["bash", str(SCRIPTS / "doc-review-run.sh")], cwd=root, env=env,
                check=True, capture_output=True, text=True)
            report = output.read_text()
            self.assertIn("**Overall verdict**: NEEDS WORK", report)
            self.assertIn("Critical=0 Major=1 Minor=0", report)
            self.assertEqual(report.count("| 1 | Same rule | Major |"), 1)
            for number in range(1, 5):
                self.assertIn(f"page-{number}.mdx:1", report)

    def test_chunk_lists_consume_large_streams(self):
        source = (SCRIPTS / "doc-review-run.sh").read_text()
        line = next(line for line in source.splitlines() if 'echo "Files in the other parts:"' in line)
        with tempfile.TemporaryDirectory() as directory:
            current = Path(directory) / "current.patch"
            other = Path(directory) / "other.patch"
            current.write_text(patch("current.mdx"))
            other.write_text("".join(patch(f"large/{index:05d}-{'x' * 100}.mdx") for index in range(5000)))
            script = 'set -euo pipefail\nparts=("$1" "$2"); pf="$1"\n' + line
            result = subprocess.run(["bash", "-c", script, "test", str(current), str(other)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(result.stdout.splitlines()), 401)

    def _run_runner(self, diff_text, env_extra):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            context = root / "context"
            context.mkdir()
            captures = root / "captures"
            captures.mkdir()
            (context / "pr-diff.patch").write_text(diff_text)
            (context / "pr-review-discussion.json").write_text(json.dumps({"title": "T", "body": "B"}))
            cli = root / "claude"
            cli.write_text(
                "#!" + sys.executable + "\n"
                "import json, os, pathlib, sys\n"
                "text = sys.stdin.read()\n"
                "pathlib.Path(os.environ['CAPTURES'], str(os.getpid()) + '.txt').write_text(text)\n"
                "print(json.dumps({'result': '### Review Report\\n**Findings**: `Critical=0 Major=0 Minor=0`\\n', 'is_error': False, 'num_turns': 1, 'duration_ms': 1}))\n"
            )
            cli.chmod(0o755)
            output = root / "report.md"
            env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                       CAPTURES=str(captures), CONTEXT_DIR=str(context),
                       POLICY_DIR=str(SCRIPTS.parent.parent / ".ai/doc-review"),
                       GITHUB_REPOSITORY="example/docs", PR_NUMBER="1",
                       BASE_SHA="a" * 40, HEAD_SHA="b" * 40, RUN_URL="https://example.com/run",
                       REVIEW_REUSE="0", REVIEW_INCREMENTAL="0", REVIEW_POST="0",
                       REVIEW_OUT=str(output), REVIEW_DISCUSSION="0", REVIEW_DEDUP="1",
                       REVIEW_INLINE_MAX="300000", REVIEW_CHUNK_MAX="1500",
                       CLAUDE_CONFIG_DIR_OVERRIDE="inherit")
            env.update(env_extra)
            subprocess.run(["bash", str(SCRIPTS / "doc-review-run.sh")], cwd=root, env=env,
                           check=True, capture_output=True, text=True)
            return output.read_text(), len(list(captures.iterdir()))

    def test_oversize_diff_skipped_after_compaction(self):
        # 60 distinct pages: over the 50-file limit, skipped without a model
        # call, but visibly (a SKIPPED comment). The skip must NOT fake a
        # zero-finding Findings line -- an unreviewed PR is not a pass.
        many = "".join(patch(f"d/{i:03d}.mdx", "x " * 5) for i in range(60))
        report, prompts = self._run_runner(many, {"REVIEW_MAX_FILES": "50"})
        self.assertIn("**Overall verdict**: SKIPPED", report)
        self.assertIn("skipped: 60 files > 50", report)
        self.assertNotIn("Critical=0 Major=0 Minor=0", report)
        self.assertNotIn("**Findings**:", report)
        self.assertEqual(prompts, 0)

    def _extract_run(self, workflow, step_name):
        # Pull a workflow step's run script verbatim, dedented like the runner
        # executes it. Shared by the gate and validator regressions.
        source = (SCRIPTS.parent / "workflows" / workflow).read_text()
        step = source.split(f"      - name: {step_name}\n", 1)[1]
        run = step.split("        run: |\n", 1)[1]
        return "\n".join(line[10:] if line.startswith("          ") else line
                         for line in run.splitlines())

    def test_skipped_report_passes_validators_and_gates(self):
        # End-to-end: the real SKIPPED report the runner emits must pass both
        # workflows' report validators AND their findings gates, for automatic
        # and manual reviews alike. Regression for the oversized-review path
        # that previously failed "exactly one Overall verdict line".
        many = "".join(patch(f"d/{i:03d}.mdx", "x " * 5) for i in range(60))
        report, _ = self._run_runner(many, {"REVIEW_MAX_FILES": "50"})
        self.assertIn("**Overall verdict**: SKIPPED", report)

        for workflow in ("doc-review-auto.yml", "doc-review.yml"):
            with self.subTest(workflow=workflow, stage="validator"):
                script = self._extract_run(workflow, "Clean Up Prior Review Comments")
                start = script.index("<<'PY'\n") + len("<<'PY'\n")
                program = script[start:script.index("\nPY", start)]
                with tempfile.TemporaryDirectory() as directory:
                    report_path = Path(directory) / "report.md"
                    report_path.write_text(report)
                    result = subprocess.run(
                        [sys.executable, "-c", program, str(report_path)],
                        env=dict(os.environ, REQUIRE_COUNTS="1", VERDICT_POLICY="new"),
                        text=True, capture_output=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            with self.subTest(workflow=workflow, stage="gate"):
                gate = self._extract_run(workflow, "Fail on Critical or Excess Major Findings")
                with tempfile.TemporaryDirectory() as directory:
                    cli = Path(directory) / "gh"
                    cli.write_text(
                        "#!" + sys.executable + "\n"
                        "import os, sys\n"
                        "assert sys.argv[1:] == ['api', 'repos/example/docs/issues/comments/123', '--jq', '.body']\n"
                        "print(os.environ['MOCK_REPORT'])\n"
                    )
                    cli.chmod(0o755)
                    result = subprocess.run(
                        ["bash", "-c", gate], text=True, capture_output=True,
                        env=dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
                                 COMMENT_ID="123", GITHUB_REPOSITORY="example/docs", MOCK_REPORT=report))
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_version_copies_collapse_under_limit(self):
        # 20 pages x 3 version trees = 60 raw files, but identical copies
        # collapse to 20 after compaction: under the limit, so the review runs.
        dup = "".join(patch(f"{v}/p{i:02d}.mdx", "x " * 5)
                      for i in range(20)
                      for v in ("v1.13.x", "v2.0.x", "v2.1.x-SNAPSHOT"))
        report, prompts = self._run_runner(dup, {"REVIEW_MAX_FILES": "50"})
        self.assertNotIn("SKIPPED", report)
        self.assertGreater(prompts, 0)

    def check_gate(self, workflow):
        # Extract the actual last workflow step; do not duplicate its logic.
        source = (SCRIPTS.parent / "workflows" / workflow).read_text()
        step = source.split("      - name: Fail on Critical or Excess Major Findings\n", 1)[1]
        run = step.split("        run: |\n", 1)[1]
        script = "\n".join(line[10:] if line.startswith("          ") else line
                           for line in run.splitlines())
        cases = (
            (0, 0, 0, 0),
            (0, 3, 0, 0),
            (0, 4, 0, 1),
            (1, 0, 0, 1),
            (1, 3, 0, 1),
            (1, 4, 0, 1),
            (0, 0, 50, 0),
            (0, 3, 50, 0),
        )
        with tempfile.TemporaryDirectory() as directory:
            cli = Path(directory) / "gh"
            cli.write_text(
                "#!" + sys.executable + "\n"
                "import os, sys\n"
                "assert sys.argv[1:] == ['api', 'repos/example/docs/issues/comments/123', '--jq', '.body']\n"
                "print(os.environ['MOCK_REPORT'])\n"
            )
            cli.chmod(0o755)
            for critical, major, minor, expected in cases:
                with self.subTest(workflow=workflow, critical=critical, major=major, minor=minor):
                    verdict = "FAIL" if expected else "NEEDS WORK" if major or minor else "PASS"
                    report = (f"**Overall verdict**: {verdict}\n"
                              f"**Findings**: `Critical={critical} Major={major} Minor={minor}`\n")
                    env = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
                               COMMENT_ID="123", GITHUB_REPOSITORY="example/docs", MOCK_REPORT=report)
                    result = subprocess.run(["bash", "-c", script], env=env, text=True,
                                            capture_output=True)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                    if critical:
                        self.assertIn(f"Review found {critical} Critical", result.stdout)
                    elif major > 3:
                        self.assertIn(f"Review found {major} Major", result.stdout)

    def test_automatic_gate_thresholds(self):
        self.check_gate("doc-review-auto.yml")

    def test_manual_gate_thresholds(self):
        self.check_gate("doc-review.yml")

    def test_checklist_severities_are_locked(self):
        # Severity drift between this repo and docs-collate lets the same
        # mistake FAIL in one and PASS in the other. Lock the severities that
        # are easiest to misgrade (kept in step with docs-collate #719).
        policy = (SCRIPTS.parent.parent / ".ai/doc-review/references/checklist.md").read_text()
        for entry in (
            "**No typos** (Critical)",
            "**Title-case headings** (Critical)",
            "**No periods in headings** (Critical)",
            "**Optional step** (Major)",
            "**Navigation separators** (Critical)",
            "**Use OpenMetadata branding** (Critical)",
        ):
            self.assertIn(entry, policy)


if __name__ == "__main__":
    unittest.main()
