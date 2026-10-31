# Oceanic: Finish MATLAB Outline Validation

## Objective

Finish the existing milestone without broadening its scope.

Remaining deliverables:
1. Correct the TaggedClass fixture expectation.
2. Fix Markdown source-link resolution.
3. Obtain a green outline test suite.
4. Add tools/check_matlab_outline.py.
5. Regenerate and verify the three owned catalogue outputs.
6. Inspect the final diff.

Repository: mk-bluebird/Oceanic.

## Restrictions

- Do not install tools, packages, dependencies, or plugins.
- Do not run cargo, rustup, rustc, or other Rust commands.
- Shell and existing Python tooling are permitted.
- Python, Lua, MATLAB, and C++ are the permitted implementation languages.
- Lua 5.4.7 or later is the only installation exception; it is unnecessary here.
- Do not modify scientific/research materials, numerical models, datasets,
  ecological claims, or attribution text.
- Do not create a new CI workflow directory.
- Do not commit, push, publish, or synchronize.
- Preserve syntactic_outline_only.
- Do not restart completed test-writing work.

Use one request stream. If a "Too many concurrent requests" connection error
appears, stop parallel requests and use bounded sequential retries. Do not
change source code to compensate for a connection error.

## Starting Check

Run:

    git status --short
    git diff --stat

Inspect only:
- tests/test_matlab_outline.py
- tools/matlab_outline.py
- tools/check_matlab_outline.py, if now present
- The three generated outline artifacts

Preserve pre-existing edits. Do not perform broad repository exploration.

The latest reported result was 27 tests with 2 failures. Reconfirm current
state rather than assuming the checkout has not changed.

## Action 1 — Correct the ctags Fixture Expectation

Locate test_ctags_numeric_line_addresses.

Inspect the synthetic MATLAB fixture and count its lines. Confirm whether
TaggedClass begins on line 9.

If confirmed:
- Change only the incorrect expected address from line 8 to line 9.
- Preserve the expected numeric ctags address format.
- Do not change generator line accounting to satisfy an incorrect fixture.
- Keep a short comment explaining the fixture line if useful.

Run the targeted test using its actual class and module names after inspection.
Do not invent an import path.

## Action 2 — Fix Markdown Links at the Renderer

Keep the regression test that resolves links relative to the Markdown file.

For docs/reference/symbols.md and a repository-relative source path such as
matlab/research/example.m, the expected relative target is:

    ../../matlab/research/example.m

Inspect render_markdown and the output-path contract.

Preferred repair:
- Derive the relative path from the Markdown output directory to the source
  file if the renderer already receives that location.
- Normalize emitted URL path separators to "/".
- Preserve existing URL encoding and line fragments.

Acceptable minimal repair:
- If docs/reference/ is intentionally fixed by the CLI contract, replace the
  incorrect "../" prefix with "../../".
- Document that fixed-location assumption in the renderer or test.

Do not:
- Resolve the Markdown test from the repository root.
- Replace local relative links with absolute machine paths.
- Remove escaping or URL encoding.
- Change symbol extraction to fix a rendering issue.

Confirm fixtures with spaces and Markdown-sensitive filenames still pass.

## Action 3 — Run the Existing Suite

Run:

    python3 -m unittest discover -s tests -p 'test_matlab_outline.py'

Required outcome:
- All existing tests pass, or each remaining failure is explicitly reported.
- No weakened assertions.
- No skipped tests merely to obtain a green result.
- No fabricated support for lexical limitations.

The previous 27-test count is a reported baseline, not a required hardcoded
count if justified regression coverage changes.

Do not regenerate the real catalogue until these fixes are verified.

## Action 4 — Add the Local Validation Wrapper

Filename: check_matlab_outline.py
Destination: tools/

Create this file only if it is still absent. If present, inspect and complete
it rather than overwriting unrelated changes.

Use this complete implementation:

```python
#!/usr/bin/env python3
"""Run MATLAB outline tests and the read-only stale-catalogue check.

Standard library only. No installation, networking, or catalogue writes.
SPDX-License-Identifier: MIT OR Apache-2.0

Attribution:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; not identity verification, consent, or authorization.
"""

from pathlib import Path
import subprocess
import sys


def main() -> int:
    root = Path(__file__).resolve().parents[2]

    required_files = (
        root / "tools" / "matlab_outline.py",
        root / "tests" / "test_matlab_outline.py",
    )
    for path in required_files:
        if not path.is_file():
            print(
                f"Missing prerequisite: {path.relative_to(root)}",
                file=sys.stderr,
            )
            return 2

    if not (root / "matlab").is_dir():
        print("Missing prerequisite directory: matlab", file=sys.stderr)
        return 2

    steps = (
        (
            "MATLAB outline tests",
            [
                sys.executable,
                "-m",
                "unittest",
                "discover",
                "-s",
                "tests",
                "-p",
                "test_matlab_outline.py",
            ],
        ),
        (
            "MATLAB outline stale-catalogue check",
            [
                sys.executable,
                "tools/matlab_outline.py",
                "--root",
                ".",
                "--source-root",
                "matlab",
                "--check",
            ],
        ),
    )

    try:
        for label, command in steps:
            print(f"Running: {label}", flush=True)
            completed = subprocess.run(
                command,
                cwd=root,
                check=False,
                timeout=600,
            )
            if completed.returncode != 0:
                print(
                    f"Failed: {label}; child exit {completed.returncode}",
                    file=sys.stderr,
                )
                return (
                    completed.returncode
                    if completed.returncode > 0
                    else 1
                )
    except subprocess.TimeoutExpired:
        print("Validation step exceeded 600 seconds.", file=sys.stderr)
        return 124
    except OSError:
        print(
            "Unable to start a validation subprocess; inspect locally.",
            file=sys.stderr,
        )
        return 2
    except KeyboardInterrupt:
        print("Validation interrupted.", file=sys.stderr)
        return 130

    print("MATLAB outline validation passed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

The wrapper:
- Uses the active Python interpreter.
- Runs sequentially.
- Uses argument lists, not shell=True.
- Stops on failure.
- Runs --check, never --write.
- Does not claim scientific validation.

Run the wrapper before regeneration if useful. With passing tests and a stale
catalogue, a nonzero stale-check result is expected and should be recorded,
not hidden.

## Action 5 — Regenerate Only the Owned Catalogue Outputs

After the suite is green, run:

    python3 tools/matlab_outline.py --root . --source-root matlab --write
    python3 tools/matlab_outline.py --root . --source-root matlab --check

Owned generated outputs:

    docs/reference/symbols.json
    docs/reference/symbols.md
    docs/reference/matlab.tags

Do not force the catalogue back to 12 files or 98 symbols.

The reported 21-file/148-symbol result may reflect source growth. Record the
actual result after the current fixes, including skipped files and diagnostics.

Inspect the generated Markdown links. Confirm that a representative linked
source resolves to its actual repository file.

## Action 6 — Verify Regeneration Determinism

From the repository root, run this byte-comparison check after an initial
successful --write and --check:

```python
from pathlib import Path
import subprocess
import sys

paths = [
    Path("docs/reference/symbols.json"),
    Path("docs/reference/symbols.md"),
    Path("docs/reference/matlab.tags"),
]

before = {path: path.read_bytes() for path in paths}

subprocess.run(
    [
        sys.executable,
        "tools/matlab_outline.py",
        "--root", ".",
        "--source-root", "matlab",
        "--write",
    ],
    check=True,
    timeout=600,
)

after = {path: path.read_bytes() for path in paths}
changed = [str(path) for path in paths if before[path] != after[path]]

if changed:
    raise SystemExit(
        "Regeneration was not byte-identical: " + ", ".join(changed)
    )

subprocess.run(
    [
        sys.executable,
        "tools/matlab_outline.py",
        "--root", ".",
        "--source-root", "matlab",
        "--check",
    ],
    check=True,
    timeout=600,
)

print("Owned catalogue outputs regenerated byte-identically.")
```

This tests deterministic output under unchanged inputs and configuration.
It does not establish extraction completeness.

## Action 7 — Run the Reusable Validation Command

Run:

    python3 tools/check_matlab_outline.py

Required result:
- Tests pass.
- Stale check passes.
- Wrapper exits 0.
- Wrapper does not regenerate artifacts.

Do not report "local validation wired" until the wrapper exists.
Do not report "local validation passed" until this command actually succeeds.

Hosted CI remains pending because no suitable workflow exists. No new
.github/workflows directory is required for this milestone.

## Action 8 — Final Diff Inspection

Run:

    git diff --check
    git diff --stat
    git status --short

Inspect:
- The corrected test.
- The Markdown renderer fix.
- The new wrapper.
- Intended generated catalogue differences.
- Any other existing generator changes already in progress.

Confirm:
- No scientific/research source was edited.
- No numerical model was changed.
- No dataset was changed.
- No attribution text was changed.
- No install, commit, push, or external publication occurred.

Do not revert unrelated pre-existing changes.

## Final Report

Report only actual results:

1. Files changed.
2. Test count, failures, errors, and skips.
3. Commands and exit codes.
4. Current source-file and symbol counts.
5. Skipped-file and diagnostic counts.
6. Representative Markdown link resolution.
7. Byte-identical regeneration result.
8. Local wrapper status.
9. Hosted CI status: pending.
10. Remaining lexical limitations.
11. Final diff-scope findings.

If quota or connection limits interrupt the work, stop with the exact remaining
command or edit. Do not repeat completed implementation tasks.

## Attribution

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Credit and configured metadata only; not identity verification, consent,
operational authorization, execution evidence, or authority.
