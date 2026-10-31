#!/usr/bin/env python3
# SOVEREIGN-ATTRIBUTION: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
# Credit and configured workstream metadata only. This attribution does not
# establish identity, verification, consent, authorization, execution
# evidence, or authority over any person or system.
"""CLI-level tests for tools/matlab_outline.py (syntactic outline only).

All MATLAB inputs are synthetic fixtures created inside temporary
directories; no research file is used as a mutable fixture. Tests exercise
the documented stdlib-lexical-fallback contract: declaration extraction on a
conservative lexical level, comment/string vetoing, repo-relative paths, and
--write/--check freshness behavior. They deliberately do NOT claim complete
MATLAB parsing, precise navigation, or source verification.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import unquote

REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR = REPO_ROOT / "tools" / "matlab_outline.py"
BACKEND = "stdlib-lexical-fallback"
ARTIFACTS = (
    "docs/reference/symbols.json",
    "docs/reference/symbols.md",
    "docs/reference/matlab.tags",
)


def run_cli(root: str, *args: str, timeout: int = 120):
    """Invoke the generator CLI without shell interpolation."""
    return subprocess.run(
        [sys.executable, str(GENERATOR), "--root", root, "--source-root", "matlab",
         "--backend", BACKEND, *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


class OutlineFixture(unittest.TestCase):
    """Base class providing a per-test temporary repository root."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="matlab-outline-test-")
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.matlab = self.root / "matlab"
        self.matlab.mkdir()

    def write_source(self, rel: str, text: str) -> Path:
        path = self.matlab / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def artefact(self, rel: str) -> Path:
        return self.root / rel

    def generate(self, *args: str):
        result = run_cli(str(self.root), *args)
        self.assertEqual(
            result.returncode, 0,
            msg=f"--write failed:\nstdout={result.stdout}\nstderr={result.stderr}",
        )
        return result

    def catalogue(self) -> dict:
        with open(self.artefact(ARTIFACTS[0]), encoding="utf-8") as handle:
            return json.load(handle)

    def symbols(self) -> list[dict]:
        return self.catalogue()["symbols"]

    def symbol_names(self) -> set[str]:
        return {symbol["name"] for symbol in self.symbols()}

    def markdown(self) -> str:
        return self.artefact(ARTIFACTS[1]).read_text(encoding="utf-8")

    def tags_text(self) -> str:
        return self.artefact(ARTIFACTS[2]).read_text(encoding="utf-8")

    def tag_lines(self) -> list[list[str]]:
        return [
            line.split("\t")
            for line in self.tags_text().splitlines()
            if line and not line.startswith("!")
        ]


# ---------------------------------------------------------------------------
# declaration extraction
# ---------------------------------------------------------------------------


class DeclarationExtractionTests(OutlineFixture):
    def test_single_line_function(self) -> None:
        self.write_source("one.m", "function y = one(x)\ny = x;\nend\n")
        self.generate("--write")
        symbol = next(s for s in self.symbols() if s["name"] == "one")
        self.assertEqual(symbol["kind"], "function")
        self.assertEqual(symbol["start_line"], 1)
        self.assertIn("y = one", symbol["signature"])

    def test_function_without_output(self) -> None:
        self.write_source("noout.m", "function noop(x)\nx = x + 1;\nend\n")
        self.generate("--write")
        symbol = next(s for s in self.symbols() if s["name"] == "noop")
        self.assertEqual(symbol["kind"], "function")
        self.assertNotIn("=", symbol["signature"].split("(")[0])

    def test_multiple_output_function(self) -> None:
        self.write_source("multi.m", "function [a, b] = multi(x)\na = x;\nb = x;\nend\n")
        self.generate("--write")
        symbol = next(s for s in self.symbols() if s["name"] == "multi")
        self.assertIn("[a, b]", symbol["signature"])

    def test_multiline_function_signature(self) -> None:
        self.write_source(
            "cont.m",
            "function out = cont(a, ...\n    b, c)\nout = a;\nend\n",
        )
        self.generate("--write")
        symbol = next(s for s in self.symbols() if s["name"] == "cont")
        # The header is one logical line starting at physical line 1.
        self.assertEqual(symbol["start_line"], 1)
        self.assertIn("(a,", symbol["signature"])
        self.assertIn("b, c)", symbol["signature"])

    def test_local_function(self) -> None:
        self.write_source(
            "mainfile.m",
            "function y = mainfile(x)\ny = helper(x);\nend\n\n"
            "function h = helper(v)\nh = v;\nend\n",
        )
        self.generate("--write")
        names = [(s["name"], s["start_line"]) for s in self.symbols()]
        self.assertIn(("mainfile", 1), names)
        self.assertIn(("helper", 5), names)
        # Lexical backend cannot attribute locals precisely: partial confidence.
        helper = next(s for s in self.symbols() if s["name"] == "helper")
        self.assertEqual(helper["extraction_confidence"], "partial")

    def test_nested_function(self) -> None:
        self.write_source(
            "outerf.m",
            "function outerf()\n    innerf();\n    function innerf()\n    end\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertIn("outerf", names)
        self.assertIn("innerf", names)
        inner = next(s for s in self.symbols() if s["name"] == "innerf")
        # Documented limitation: nesting is not resolved by the lexical backend.
        self.assertIsNone(inner["parent_scope"])
        self.assertIsNone(inner["end_line"])

    def test_classdef_and_method(self) -> None:
        self.write_source(
            "Widget.m",
            "classdef (Abstract) Widget < base.Thing\n"
            "    properties\n        P\n    end\n"
            "    methods\n"
            "        function self = makeWidget(v)\n            self.P = v;\n        end\n"
            "        function r = compute(self, t)\n            r = self.P + t;\n        end\n"
            "    end\nend\n",
        )
        self.generate("--write")
        kinds = {(s["name"], s["kind"]) for s in self.symbols()}
        self.assertIn(("Widget", "class"), kinds)
        self.assertIn(("compute", "function"), kinds)
        cls = next(s for s in self.symbols() if s["kind"] == "class")
        self.assertEqual(cls["extraction_confidence"], "syntactic")
        method = next(s for s in self.symbols() if s["name"] == "compute")
        # Declared limitation: method binding stays partial with null scope.
        self.assertEqual(method["extraction_confidence"], "partial")
        self.assertIsNone(method["parent_scope"])


# ---------------------------------------------------------------------------
# comments and strings
# ---------------------------------------------------------------------------


class CommentAndStringTests(OutlineFixture):
    def test_line_comment_does_not_create_symbol(self) -> None:
        self.write_source(
            "lc.m",
            "% function ghost(a)\n%% function section_ghost(b)\n"
            "x = 1; % function tail_ghost(c)\n"
            "function y = lc(x)\ny = x;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertIn("lc", names)
        for forbidden in ("ghost", "section_ghost", "tail_ghost"):
            self.assertNotIn(forbidden, names)

    def test_block_comment_does_not_create_symbol(self) -> None:
        self.write_source(
            "bc.m",
            "%%{\nfunction hidden1(k)\nhidden1 = 1;\nend\n%}\n"
            "function y = visible(v)\ny = v;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertNotIn("hidden1", names)
        self.assertIn("visible", names)
        # A standalone %} closes the block; code after it is scanned again.
        self.write_source(
            "bc2.m",
            "%%{\nfunction still_hidden(m)\nend\n%}\nfunction w = after_block(n)\nw = n;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertNotIn("still_hidden", names)
        self.assertIn("after_block", names)
        # Delimiters embedded in other text are not block-comment delimiters.
        self.write_source(
            "bc3.m",
            "x = 'see %%{ docs';\n% note %%{ inline is just comment text\n"
            "function q = bc3_fn(p)\nq = p;\nend\n",
        )
        self.generate("--write")
        self.assertIn("bc3_fn", self.symbol_names())

    def test_function_text_inside_string_does_not_create_symbol(self) -> None:
        self.write_source(
            "str.m",
            "s = 'function fake(q)';\nt = ['function also_fake(r)'];\n"
            "function y = str(x)\ny = x;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertNotIn("fake", names)
        self.assertNotIn("also_fake", names)
        self.assertIn("str", names)

    def test_percent_inside_string_is_not_comment_start(self) -> None:
        self.write_source(
            "pct.m",
            "fmt = 'ratio 50%% done';\n% function pct_ghost(z)\n"
            "function y = pct(x)\ny = sprintf(fmt, x); % trailing comment\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertIn("pct", names)
        self.assertNotIn("pct_ghost", names)

    def test_escaped_quote_handling(self) -> None:
        self.write_source(
            "esc.m",
            "msg = 'it''s a function decoy(t) inside a literal';\n"
            "function y = esc(x)\ny = x;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertNotIn("decoy", names)
        self.assertIn("esc", names)

    def test_transpose_quote_is_not_misread_as_string(self) -> None:
        self.write_source(
            "tr.m",
            "A = [1 2; 3 4];\nB = A';\nC = B' * 2;\n"
            "function y = tr(x)\ny = x;\nend\n",
        )
        self.generate("--write")
        names = self.symbol_names()
        self.assertIn("tr", names)
        # If transpose quotes were treated as string starts, scanning would
        # swallow following lines; the declaration must still be found.
        self.assertEqual(
            next(s for s in self.symbols() if s["name"] == "tr")["start_line"], 4
        )


# ---------------------------------------------------------------------------
# paths and formats
# ---------------------------------------------------------------------------


class PathsAndFormatsTests(OutlineFixture):
    def test_non_ascii_symbol_or_path_preserved(self) -> None:
        # Regression: the fallback name pattern once rejected non-ASCII
        # identifiers outright (skipped as invalid); they must now be kept
        # verbatim in JSON, Markdown, and tags.
        self.write_source("ünïcode_fn.m", "function res = ñame(ärg)\nres = ärg;\nend\n")
        self.write_source("café/naïve.m", "function o = óbj(i)\no = i;\nend\n")
        self.generate("--write")
        names = self.symbol_names()
        self.assertIn("ñame", names)
        self.assertIn("óbj", names)
        files = {s["file"] for s in self.symbols()}
        self.assertIn("matlab/ünïcode_fn.m", files)
        self.assertIn("matlab/café/naïve.m", files)
        raw_json = self.artefact(ARTIFACTS[0]).read_bytes()
        self.assertIn("ñame".encode("utf-8"), raw_json)  # ensure_ascii=False
        md = self.markdown()
        self.assertIn("ñame", md)
        tag_names = {fields[0] for fields in self.tag_lines()}
        self.assertIn("ñame", tag_names)

    def test_paths_remain_repository_relative(self) -> None:
        self.write_source("sub/dir/mod.m", "function y = mod(x)\ny = x;\nend\n")
        self.generate("--write")
        serialized = json.dumps(self.catalogue(), ensure_ascii=False)
        self.assertNotIn(str(self.root), serialized)
        home = os.path.expanduser("~")
        if home and home != "/":
            self.assertNotIn(home, serialized)
        for symbol in self.symbols():
            self.assertTrue(symbol["file"].startswith("matlab/"))
            self.assertFalse(os.path.isabs(symbol["file"]))
            self.assertNotIn("..", symbol["file"].split("/"))
            self.assertNotIn("\\", symbol["file"])

    def test_markdown_escaping(self) -> None:
        self.write_source(
            "weird [name] (x)*y_.m",
            "function v = weird(a)\nv = a;\nend\n",
        )
        self.generate("--write")
        md = self.markdown()
        heading = next(
            line for line in md.splitlines() if line.startswith("### [`")
        )
        # Markdown-sensitive characters in the displayed label are escaped.
        self.assertIn("\\[name\\]", heading)
        self.assertIn("weird", md)
        row = next(line for line in md.splitlines() if line.startswith("| function | weird"))
        self.assertIn("\\(a\\)", row)

    def test_markdown_links_resolve_to_expected_source(self) -> None:
        self.write_source(
            "dir with space/weird [name] (x).m",
            "function v = weird(a)\nv = a;\nend\n",
        )
        self.generate("--write")
        md = self.markdown()
        # Collect every Markdown link target emitted for source files.
        targets = set()
        for line in md.splitlines():
            if "](" not in line:
                continue
            for chunk in line.split("](")[1:]:
                target = chunk.rstrip(")").split("#")[0]
                if target.startswith("../matlab/"):
                    targets.add(target)
        self.assertTrue(targets)
        expected = (self.matlab / "dir with space" / "weird [name] (x).m").resolve()
        resolved_targets = {
            (self.artefact(ARTIFACTS[1]).parent / unquote(target)).resolve()
            for target in targets
        }
        self.assertIn(expected, resolved_targets)

    def test_ctags_numeric_line_addresses(self) -> None:
        self.write_source(
            "tagged.m",
            "\n\nfunction y = tagged(x)\ny = x;\nend\n\n"
            "% a comment line\n\nclassdef TaggedClass\nend\n",
        )
        self.generate("--write")
        tags = self.tags_text()
        self.assertTrue(tags.startswith("!_TAG_FILE_FORMAT\t2"))
        rows = {fields[0]: fields for fields in self.tag_lines()}
        self.assertIn("tagged", rows)
        self.assertEqual(rows["tagged"][2], "3;\"")
        self.assertIn("line:3", rows["tagged"])
        self.assertIn("kind:f", rows["tagged"])
        self.assertIn("TaggedClass", rows)
        self.assertEqual(rows["TaggedClass"][2], "8;\"")
        self.assertIn("kind:c", rows["TaggedClass"])
        for fields in self.tag_lines():
            self.assertRegex(fields[2], r'^\d+;"$')
            self.assertNotIn("\t", fields[0])

    def test_json_schema_metadata_preserved(self) -> None:
        # Structural check of the emitted JSON's actual documented shape.
        # This is not a formal JSON-Schema validation run.
        self.write_source("meta.m", "function y = meta(x)\ny = x;\nend\n")
        self.generate("--write")
        catalogue = self.catalogue()
        self.assertEqual(catalogue["schema_version"], "1.0.0")
        self.assertEqual(catalogue["generator_marker"], "matlab-outline:generated")
        self.assertEqual(catalogue["precision"], "syntactic_outline_only")
        self.assertEqual(catalogue["extraction_backend"], BACKEND)
        self.assertEqual(
            catalogue["attribution"], "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
        )
        self.assertEqual(catalogue["source_roots"], ["matlab"])
        coverage = catalogue["coverage"]
        self.assertEqual(coverage["symbol_count"], len(catalogue["symbols"]))
        self.assertEqual(coverage["files_scanned"], 1)
        self.assertIsInstance(catalogue["interpretation_limits"], list)
        for symbol in catalogue["symbols"]:
            self.assertEqual(
                set(symbol),
                {
                    "file", "language", "kind", "name", "signature",
                    "start_line", "end_line", "parent_scope",
                    "extraction_confidence",
                },
            )
            self.assertEqual(symbol["language"], "matlab")

    def test_line_ranges_match_fixture(self) -> None:
        self.write_source(
            "range.m",
            "% leading comment\n\nfunction a = first(x)\na = x;\nend\n\n"
            "function [p, q] = second(v)\np = v; q = v;\nend\n",
        )
        self.generate("--write")
        by_name = {s["name"]: s for s in self.symbols()}
        self.assertEqual(by_name["first"]["start_line"], 3)
        self.assertEqual(by_name["second"]["start_line"], 7)
        # Declared limitation: extents are unknown (null), never guessed.
        self.assertIsNone(by_name["first"]["end_line"])
        self.assertIsNone(by_name["second"]["end_line"])
        tags = {fields[0]: fields for fields in self.tag_lines()}
        self.assertEqual(tags["first"][2], "3;\"")
        self.assertEqual(tags["second"][2], "7;\"")


# ---------------------------------------------------------------------------
# CLI behavior
# ---------------------------------------------------------------------------


class CliBehaviorTests(OutlineFixture):
    def test_output_is_deterministic(self) -> None:
        self.write_source("det.m", "function y = det(x)\ny = x;\nend\n")
        self.generate("--write")
        first = {rel: self.artefact(rel).read_bytes() for rel in ARTIFACTS}
        self.generate("--write")
        second = {rel: self.artefact(rel).read_bytes() for rel in ARTIFACTS}
        self.assertEqual(first, second)

    def test_check_succeeds_after_write(self) -> None:
        self.write_source("ok.m", "function y = ok(x)\ny = x;\nend\n")
        self.generate("--write")
        result = run_cli(str(self.root), "--check")
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("outputs are current", result.stdout)

    def test_check_detects_stale_output(self) -> None:
        self.write_source("stale.m", "function y = stale(x)\ny = x;\nend\n")
        self.generate("--write")
        self.write_source("stale.m", "function y = stale(x)\ny = x;\nend\n\nfunction z = added(w)\nz = w;\nend\n")
        result = run_cli(str(self.root), "--check")
        self.assertEqual(result.returncode, 1, msg=result.stdout)
        self.assertIn("stale", result.stderr)

    def test_check_detects_missing_output(self) -> None:
        self.write_source("gone.m", "function y = gone(x)\ny = x;\nend\n")
        self.generate("--write")
        self.artefact(ARTIFACTS[0]).unlink()
        result = run_cli(str(self.root), "--check")
        self.assertEqual(result.returncode, 1, msg=result.stdout)
        self.assertIn("missing", result.stderr)

    def test_check_does_not_modify_outputs(self) -> None:
        self.write_source("mut.m", "function y = mut(x)\ny = x;\nend\n")
        self.generate("--write")
        # Make the index stale, then prove --check leaves bytes untouched.
        self.write_source("mut.m", "function y = mut(x)\ny = x;\nend\n\nfunction n = newf(o)\nn = o;\nend\n")
        before = {rel: self.artefact(rel).read_bytes() for rel in ARTIFACTS}
        result = run_cli(str(self.root), "--check")
        self.assertEqual(result.returncode, 1)
        after = {rel: self.artefact(rel).read_bytes() for rel in ARTIFACTS}
        self.assertEqual(before, after)

    def test_cli_returns_nonzero_for_invalid_input(self) -> None:
        cases = [
            ([], 2),                                   # neither --write nor --check
            (["--write", "--check"], 2),               # mutually exclusive modes
            (["--write", "--root", "no/such/directory"], 2),
            (["--write", "--source-root", "../escape"], 2),
            (["--write", "--backend", "not-a-backend"], 2),
        ]
        for args, expected in cases:
            result = subprocess.run(
                [sys.executable, str(GENERATOR), *args],
                capture_output=True,
                text=True,
                timeout=120,
            )
            self.assertEqual(
                result.returncode, expected,
                msg=f"args={args}\nstdout={result.stdout}\nstderr={result.stderr}",
            )


# ---------------------------------------------------------------------------
# staleness lifecycle in a temporary checkout shape (Action 3)
# ---------------------------------------------------------------------------


class StalenessLifecycleTests(OutlineFixture):
    def test_full_staleness_cycle_in_temporary_root(self) -> None:
        self.write_source("core/core_fn.m", "function y = core_fn(x)\ny = x;\nend\n")
        # 2. --write
        self.generate("--write")
        for rel in ARTIFACTS:
            self.assertTrue(self.artefact(rel).is_file(), rel)
        # 3. --check succeeds
        self.assertEqual(run_cli(str(self.root), "--check").returncode, 0)
        # 4. add a real function declaration
        self.write_source(
            "core/extra.m",
            "function e = extra_fn(v)\ne = v;\nend\n",
        )
        # 5. --check exits nonzero
        stale_result = run_cli(str(self.root), "--check")
        self.assertEqual(stale_result.returncode, 1)
        # 6. --check did not rewrite anything: the committed catalogue must
        #    still reflect the pre-change state.
        self.assertNotIn("extra_fn", self.symbol_names())
        # 7. --write
        self.generate("--write")
        self.assertIn("extra_fn", self.symbol_names())
        # 8. --check succeeds again
        self.assertEqual(run_cli(str(self.root), "--check").returncode, 0)


if __name__ == "__main__":
    unittest.main()
