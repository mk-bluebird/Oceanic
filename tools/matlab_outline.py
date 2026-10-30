#!/usr/bin/env python3
# SOVEREIGN-ATTRIBUTION: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
# Credit and configured workstream metadata only. This attribution does not
# establish identity, verification, consent, authorization, execution
# evidence, or authority over any person or system.
"""Bounded, additive MATLAB source-navigation generator for Oceanic.

This tool produces three owned artifacts:

  * ``docs/reference/symbols.json`` - machine-readable symbol catalogue
  * ``docs/reference/symbols.md``   - human-readable Markdown catalogue
  * ``docs/reference/matlab.tags``  - ctags-compatible numeric-line tag file

It is a *syntactic outline* generator. It does not enable GitHub's native
MATLAB outline, precise reference resolution, or a code-navigation service,
and it does not extract properties, variable references, or method bindings.

Backends (selected deterministically, never silently switched):

  * ``tree-sitter-matlab`` - used only when an already installed MATLAB
    grammar passes a bounded local capability probe. Nothing is installed.
  * ``stdlib-lexical-fallback`` - a conservative standard-library lexical
    scanner. It is an outline approximation, not a full MATLAB parser.
    Unknown end lines and unknown parent scopes are recorded as ``null``.

Exit statuses:
  0 success / outputs current
  1 generated outputs missing or stale
  2 invalid arguments or configuration
  3 extraction, validation, or I/O failure
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from urllib.parse import quote as _url_quote

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
SCHEMA_VERSION = "1.0.0"
GENERATOR_VERSION = "matlab-outline/1.0.0"
PRECISION = "syntactic_outline_only"

BACKEND_TREE_SITTER = "tree-sitter-matlab"
BACKEND_FALLBACK = "stdlib-lexical-fallback"

DEFAULT_SOURCE_ROOTS = ("matlab",)
OUTPUT_RELPATHS = (
    "docs/reference/symbols.json",
    "docs/reference/symbols.md",
    "docs/reference/matlab.tags",
)

MARKDOWN_MARKER = "<!-- matlab-outline:generated -->"
TAGS_MARKER = "!_TAG_FILE_FORMAT\t2\t/extended format/"
JSON_MARKER_KEY = "generator_marker"
JSON_MARKER_VALUE = "matlab-outline:generated"

MAX_DIAGNOSTICS = 200
DIAGNOSTIC_TEXT_LIMIT = 160

INTERPRETATION_LIMITS = (
    "Syntactic outline only: no type inference, no scope resolution, "
    "no call-graph or reference index.",
    "Not GitHub's native symbol outline; generating these files does not "
    "enable GitHub's MATLAB code-navigation service.",
    "end_line and parent_scope are null whenever the selected backend "
    "cannot establish them; null means unknown, not absent.",
    "No properties, variable references, or method bindings are extracted "
    "in this milestone.",
    "Signatures are public-output candidates only after the selected roots "
    "and generated changes have been reviewed; source existence does not "
    "imply release permission.",
    "Do not pass .lua files to the MATLAB backend; Lua indexing requires a "
    "separate extractor.",
)


class OutlineError(Exception):
    """Raised for extraction, validation, or I/O failures (exit status 3)."""


# --------------------------------------------------------------------------
# discovery
# --------------------------------------------------------------------------

_MATLAB_EXT_CANDIDATE_SUFFIXES = (".m",)
_OBJECTIVE_C_SUFFIXES = (".mm",)


def _is_within(child: str, parent: str) -> bool:
    child_n = os.path.normpath(child)
    parent_n = os.path.normpath(parent)
    return child_n == parent_n or child_n.startswith(parent_n + os.sep)


def discover_sources(root: str, source_roots) -> dict:
    """Collect MATLAB candidate files beneath the approved source roots.

    Returns ``{"files": [...], "skipped": [{"path", "reason"}...]}`` with
    deterministic ordering and repository-relative POSIX paths. Directory
    symlinks are never followed, and no path may escape the repository root.
    """
    root_abs = os.path.abspath(root)
    files: list[str] = []
    skipped: list[dict] = []

    for rel in sorted(set(source_roots)):
        norm = os.path.normpath(rel).replace("\\", "/")
        if norm.startswith("..") or os.path.isabs(norm) or norm == ".":
            raise OutlineError(f"source root escapes repository root: {rel!r}")
        abs_root = os.path.join(root_abs, norm)
        if not _is_within(abs_root, root_abs):
            raise OutlineError(f"source root escapes repository root: {rel!r}")
        if os.path.islink(abs_root):
            skipped.append({"path": norm, "reason": "source-root-is-symlink"})
            continue
        if not os.path.isdir(abs_root):
            skipped.append({"path": norm, "reason": "source-root-missing"})
            continue

        for dirpath, dirnames, filenames in os.walk(abs_root, followlinks=False):
            kept = []
            for name in sorted(dirnames):
                candidate = os.path.join(dirpath, name)
                if os.path.islink(candidate):
                    skipped.append(
                        {
                            "path": _rel_posix(candidate, root_abs),
                            "reason": "directory-symlink-not-followed",
                        }
                    )
                    continue
                kept.append(name)
            dirnames[:] = kept

            for name in sorted(filenames):
                abs_path = os.path.join(dirpath, name)
                rel_path = _rel_posix(abs_path, root_abs)
                if os.path.islink(abs_path):
                    skipped.append({"path": rel_path, "reason": "file-symlink-skipped"})
                    continue
                lowered = name.lower()
                if lowered.endswith(_OBJECTIVE_C_SUFFIXES):
                    skipped.append({"path": rel_path, "reason": "objective-c-extension"})
                    continue
                if not lowered.endswith(_MATLAB_EXT_CANDIDATE_SUFFIXES):
                    continue
                # The extension alone does not prove a file is MATLAB.
                try:
                    head = _read_bytes(abs_path, limit=4096)
                except OSError as exc:
                    skipped.append({"path": rel_path, "reason": f"read-error: {exc}"})
                    continue
                if _looks_like_objective_c(head):
                    skipped.append({"path": rel_path, "reason": "objective-c-content"})
                    continue
                files.append(rel_path)

    files.sort()
    skipped.sort(key=lambda item: (item["path"], item["reason"]))
    return {"files": files, "skipped": skipped}


def _rel_posix(abs_path: str, root_abs: str) -> str:
    rel = os.path.relpath(abs_path, root_abs)
    return rel.replace(os.sep, "/")


def _read_bytes(path: str, limit: int | None = None) -> bytes:
    with open(path, "rb") as handle:
        if limit is None:
            return handle.read()
        return handle.read(limit)


_OBJCTOKENS = (
    b"#import",
    b"#include <Foundation",
    b"@interface",
    b"@implementation",
    b"NSLog(",
    b"initWith",
)


def _looks_like_objective_c(head: bytes) -> bool:
    if b"@interface" in head or b"@implementation" in head:
        return True
    hits = sum(1 for token in _OBJCTOKENS if token in head)
    return hits >= 2


# --------------------------------------------------------------------------
# shared signature helpers
# --------------------------------------------------------------------------

_IDENT_RE = re.compile(r"[A-Za-z_\u00a1-\uffff][\w\u00a1-\uffff]*")


def _clean(text: str) -> str:
    text = re.sub(r"\s+", " ", text)
    return text.strip().rstrip(";").strip()


def _normalize_signature(sig: str) -> str:
    sig = _clean(sig)
    sig = sig.replace("\t", " ")
    if len(sig) > 300:
        sig = sig[:300].rstrip() + " ..."
    return sig


def _first_identifier(text: str) -> str | None:
    match = _IDENT_RE.search(text)
    return match.group(0) if match else None


def _make_symbol(**kwargs) -> dict:
    base = {
        "file": None,
        "language": "matlab",
        "kind": "function",
        "name": None,
        "signature": "",
        "start_line": None,
        "end_line": None,
        "parent_scope": None,
        "extraction_confidence": "partial",
    }
    base.update(kwargs)
    return base


# --------------------------------------------------------------------------
# tree-sitter backend (optional, probed, never installed here)
# --------------------------------------------------------------------------

_TS_PROBE_SAMPLES = {
    "plain": b"function y = f(x)\ny = x;\nend\n",
    "multioutput": b"function [a, b] = g(x)\na = x; b = x;\nend\n",
    "classdef": b"classdef (Abstract) C < B\nend\n",
    "block_comment": b"%%{\nfunction hidden(z)\nz=z;\nend\n%}\n",
    "string": b"s = 'function fake(q)';\n",
}
_TS_REQUIRED_NODE_TYPES = {"function_definition", "class_definition", "identifier"}


def detect_backend() -> str:
    """Return the backend that generation *and* checking will both use.

    The probe is bounded and local: it verifies the constructor signature,
    node structure, and comment/string handling of the installed grammar.
    Any doubt falls back to the lexical scanner. Nothing is installed.
    """
    try:
        from tree_sitter import Language, Parser  # noqa: F401  (API shape check)
        import tree_sitter_language_pack as pack  # type: ignore
    except Exception:
        return BACKEND_FALLBACK

    try:
        language = pack.get_language("matlab")
        if not isinstance(language, Language):
            return BACKEND_FALLBACK
        parser = Parser(language)
        observed_types: set[str] = set()
        for name, sample in sorted(_TS_PROBE_SAMPLES.items()):
            tree = parser.parse(sample)
            root = tree.root_node
            for node in _iter_nodes(root):
                observed_types.add(node.type)
            if name == "block_comment" and root.has_error:
                return BACKEND_FALLBACK
            if name == "string" and any(t == "function_definition" for t in observed_types):
                return BACKEND_FALLBACK
        if not _TS_REQUIRED_NODE_TYPES.issubset(observed_types):
            return BACKEND_FALLBACK
        if not hasattr(parser, "parse"):
            return BACKEND_FALLBACK
    except Exception:
        return BACKEND_FALLBACK
    return BACKEND_TREE_SITTER


def _iter_nodes(node):
    stack = [node]
    while stack:
        current = stack.pop()
        yield current
        stack.extend(current.children)


def _ts_extract(source_bytes: bytes, rel_path: str) -> tuple[list, list]:
    """Tree-sitter outline with a bounded lexical cross-check.

    The grammar decides what is a declaration; the conservative scanner of
    :func:`_split_logical_lines` only vetoes declarations whose header text
    starts inside a comment or a character literal. A disagreement is recorded
    as a diagnostic instead of being silently accepted or rejected.
    """
    from tree_sitter import Parser
    import tree_sitter_language_pack as pack

    symbols: list[dict] = []
    diagnostics: list[dict] = []
    vetoed_lines = _comment_or_literal_start_lines(source_bytes)

    def walk(node, class_stack):
        for child in node.children:
            if child.type == "function_definition":
                line = child.start_point.row + 1
                if line in vetoed_lines:
                    diagnostics.append(
                        {
                            "file": rel_path,
                            "line": line,
                            "code": "backend-disagreement-comment",
                            "detail": (
                                f"function header at line {line} starts inside a "
                                "comment or character literal and was skipped"
                            ),
                        }
                    )
                    continue
                top = len(class_stack) == 0
                scope = class_stack[-1] if class_stack else None
                symbol, note = _ts_function_symbol(child, rel_path, scope, top)
                if symbol is not None:
                    symbols.append(symbol)
                if note is not None:
                    diagnostics.append(note)
                walk(child, class_stack)
            elif child.type == "class_definition":
                cline = child.start_point.row + 1
                if cline in vetoed_lines:
                    diagnostics.append(
                        {
                            "file": rel_path,
                            "line": cline,
                            "code": "backend-disagreement-comment",
                            "detail": (
                                f"class header at line {cline} starts inside a "
                                "comment or character literal and was skipped"
                            ),
                        }
                    )
                    continue
                name, note = _ts_class_name(child, rel_path)
                if note is not None:
                    diagnostics.append(note)
                stack = class_stack + ([name] if name else list(class_stack))
                symbol = _ts_class_symbol(child, rel_path, name)
                if symbol is not None:
                    symbols.append(symbol)
                walk(child, stack)
            elif child.type in ("ERROR", "MISSING"):
                diagnostics.append(
                    {
                        "file": rel_path,
                        "line": child.start_point.row + 1,
                        "code": "syntax-error-node",
                        "detail": f"unparsable region at line {child.start_point.row + 1}",
                    }
                )
            else:
                walk(child, class_stack)

    try:
        parser = Parser(pack.get_language("matlab"))
        tree = parser.parse(source_bytes)
    except Exception as exc:  # pragma: no cover - environment dependent
        raise OutlineError(f"tree-sitter parse failed for {rel_path}: {exc}") from exc

    walk(tree.root_node, [])
    return symbols, diagnostics


def _comment_or_literal_start_lines(source_bytes: bytes) -> set:
    """Lines whose visible code begins inside a comment or char literal.

    Used only to veto tree-sitter declaration nodes; it never adds symbols.
    """
    text = source_bytes.decode("utf-8", errors="replace")
    physical = text.splitlines()
    vetoed: set[int] = set()
    in_block_comment = False
    for number, raw in enumerate(physical, start=1):
        if in_block_comment:
            vetoed.add(number)
            if raw.strip() == "%}":
                in_block_comment = False
            continue
        if _BLOCK_COMMENT_START.match(raw):
            vetoed.add(number)
            in_block_comment = True
            continue
        stripped = raw.lstrip()
        if stripped.startswith("%"):
            vetoed.add(number)
            continue
        if _starts_inside_char_literal(raw):
            vetoed.add(number)
    return vetoed


def _starts_inside_char_literal(line: str) -> bool:
    """True when the first non-space token is the tail of an unterminated '...'."""
    index = 0
    while index < len(line) and line[index].isspace():
        index += 1
    if index >= len(line) or line[index] != "'":
        return False
    before = line[:index].rstrip()
    return before.endswith("=") or before.endswith("(") or before.endswith("[") or before.endswith(",")


def _named_child(node, type_name):
    for child in node.children:
        if child.type == type_name:
            return child
    return None


def _ts_class_name(node, rel_path):
    ident = _named_child(node, "identifier")
    if ident is None:
        return None, {
            "file": rel_path,
            "line": node.start_point.row + 1,
            "code": "classdef-name-ambiguous",
            "detail": "class declaration without a recognizable name was skipped",
        }
    return ident.text.decode("utf-8", "replace"), None


def _ts_class_symbol(node, rel_path, name):
    if name is None:
        return None
    header_end = node.start_point.row + 1
    for child in node.children:
        if child.type in ("properties", "methods", "events", "function_definition"):
            break
        header_end = max(header_end, child.end_point.row + 1)
    return _make_symbol(
        file=rel_path,
        kind="class",
        name=name,
        signature=_normalize_signature(node.text.decode("utf-8", "replace")),
        start_line=node.start_point.row + 1,
        end_line=node.end_point.row + 1,
        parent_scope=None,
        extraction_confidence="syntactic",
    )


def _ts_function_symbol(node, rel_path, scope, top_level):
    name_node = None
    output_node = None
    args_node = None
    for child in node.children:
        if child.type == "function_output":
            output_node = child
        elif child.type == "identifier" and name_node is None:
            name_node = child
        elif child.type == "function_arguments":
            args_node = child
    if name_node is None:
        return None, {
            "file": rel_path,
            "line": node.start_point.row + 1,
            "code": "function-name-ambiguous",
            "detail": "function declaration without a recognizable name was skipped",
        }
    parts = []
    if output_node is not None:
        parts.append(output_node.text.decode("utf-8", "replace").strip())
    parts.append(name_node.text.decode("utf-8", "replace"))
    if args_node is not None:
        parts.append(args_node.text.decode("utf-8", "replace"))
    signature = _normalize_signature(" ".join(parts))
    confidence = "syntactic" if top_level else "partial"
    note = None
    if not top_level and scope is not None:
        note = {
            "file": rel_path,
            "line": node.start_point.row + 1,
            "code": "method-binding-partial",
            "detail": (
                f"method-like function inside class {scope!r}; enclosing class "
                "recorded but binding left partial"
            ),
        }
    symbol = _make_symbol(
        file=rel_path,
        kind="function",
        name=name_node.text.decode("utf-8", "replace"),
        signature=signature,
        start_line=node.start_point.row + 1,
        end_line=node.end_point.row + 1,
        parent_scope=scope,
        extraction_confidence=confidence,
    )
    return symbol, note


# --------------------------------------------------------------------------
# conservative stdlib lexical fallback
# --------------------------------------------------------------------------

_BLOCK_COMMENT_START = re.compile(r"^\s*%%\{[^\n]*$")
_LINE_COMMENT = re.compile(r"%")
_CONTINUATION = re.compile(r"(\.\.\.[^\n]*)$")
_DECL_FUNCTION = re.compile(r"^function\b")
_DECL_CLASSDEF = re.compile(r"^classdef\b")
_ATTR_LIST = re.compile(r"^\(([^()]*)\)\s*(.*)$")
_OUTPUT_BRACKET = re.compile(r"^\[([^\]]*)\]\s*=\s*(.+)$")
_OUTPUT_SINGLE = re.compile(r"^([A-Za-z_][\w]*)\s*=\s*(.+)$")


def _split_logical_lines(text: str) -> list[tuple[int, int, str]]:
    """Split into logical lines, honouring comments, strings, and ``...``.

    Returns tuples of ``(logical_start_row, physical_end_row, joined_text)``
    using one-based row numbers. Lexical state (single-quoted literals,
    transpose ambiguity, line comments, and ``%%{ ... %}`` block comments) is
    tracked before any declaration keyword is considered.
    """
    physical = text.splitlines()
    logical: list[tuple[int, int, str]] = []
    in_block_comment = False
    index = 0
    total = len(physical)
    while index < total:
        raw = physical[index]
        row = index + 1
        if in_block_comment:
            if raw.strip() == "%}":
                in_block_comment = False
            index += 1
            continue
        if _BLOCK_COMMENT_START.match(raw):
            in_block_comment = True
            index += 1
            continue
        stripped = _strip_non_code(raw)
        start_row = row
        pieces = [stripped]
        end_row = row
        continuation = _continuation_comment(stripped)
        while continuation is not None and index + 1 < total:
            index += 1
            nxt = physical[index]
            if in_block_comment:
                if nxt.strip() == "%}":
                    in_block_comment = False
                continue
            if _BLOCK_COMMENT_START.match(nxt):
                in_block_comment = True
                continue
            end_row = index + 1
            body = _strip_non_code(nxt)
            pieces.append(body[: continuation[0]].rstrip())
            continuation = _continuation_comment(body)
        logical.append((start_row, end_row, " ".join(p for p in pieces if p)))
        index += 1
    return logical


def _continuation_comment(stripped: str):
    """Return (dot_index, comment_text) if a line ends in a ``...`` continuation."""
    match = re.search(r"\.\.\.([^\n]*)$", stripped)
    if not match:
        return None
    tail = match.group(1)
    if re.match(r"^[\s%]*$", tail):
        return (match.start(), tail.strip())
    return None


def _strip_non_code(line: str) -> str:
    """Remove string contents and comments from a single physical line.

    Apostrophe/transpose ambiguity is handled conservatively: when a quote
    follows an operand-like character it is read as the transpose operator
    (kept verbatim) instead of opening a character literal. Unpaired residue
    can remain, but it never begins with ``function`` or ``classdef``, so no
    symbol is invented from it.
    """
    out: list[str] = []
    i = 0
    n = len(line)
    in_string = False
    while i < n:
        ch = line[i]
        if in_string:
            if ch == "'":
                if i + 1 < n and line[i + 1] == "'":
                    i += 2
                    continue
                in_string = False
            i += 1
            continue
        if ch == "%":
            break
        if ch == "[":
            j = _try_char_array_end(line, i)
            if j is not None:
                out.append(line[i : j + 1])
                i = j + 1
                continue
        if ch == "'":
            prev_idx = i - 1
            while prev_idx >= 0 and line[prev_idx].isspace():
                prev_idx -= 1
            prev = line[prev_idx] if prev_idx >= 0 else ""
            prev_is_operand = prev != "" and (prev.isalnum() or prev in ")]}_")
            if prev_is_operand:
                # Apostrophe/transpose ambiguity: treat conservatively as a
                # transpose operator, do not enter string state, keep it.
                out.append(ch)
                i += 1
                continue
            in_string = True
            out.append("''")
            i += 1
            continue
        out.append(ch)
        i += 1
    if in_string:
        out.append(" % unterminated-string-assumed-comment")
    return "".join(out).rstrip()


def _try_char_array_end(line: str, start: int) -> int | None:
    """Detect a char-array literal ``['literal' ...]`` and return its end index."""
    depth = 0
    i = start
    n = len(line)
    saw_quote = False
    while i < n:
        ch = line[i]
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
            if depth == 0:
                return i if saw_quote else None
        elif ch == "'":
            if saw_quote and i + 1 < n and line[i + 1] == "'":
                i += 1
            else:
                saw_quote = True
        elif ch == "%" and depth == 1:
            return None
        i += 1
    return None


def _fallback_parse_declaration(text: str) -> dict | None:
    """Parse one logical line (already comment/string free) as a declaration."""
    stripped = text.strip()
    if not stripped:
        return None
    class_match = _DECL_CLASSDEF.match(stripped)
    if class_match:
        rest = stripped[class_match.end() :].strip()
        name = _classdef_name(rest)
        if name is None:
            return {"status": "ambiguous", "kind": "class", "text": stripped}
        return {
            "status": "ok",
            "kind": "class",
            "name": name,
            "signature": _normalize_signature(stripped),
            "outputs": [],
            "arguments": "",
        }
    func_match = _DECL_FUNCTION.match(stripped)
    if not func_match:
        return None
    rest = stripped[func_match.end() :].strip()
    if not rest:
        return {"status": "invalid", "kind": "function", "text": stripped}
    outputs: list[str] = []
    bracket = _OUTPUT_BRACKET.match(rest)
    if bracket:
        outputs = [o.strip() for o in bracket.group(1).split(",") if o.strip()]
        rest = bracket.group(2).strip()
    else:
        single = _OUTPUT_SINGLE.match(rest)
        if single:
            outputs = [single.group(1)]
            rest = single.group(2).strip()
    name_match = re.match(r"([A-Za-z_][\w\u00a1-\uffff]*)", rest)
    if name_match is None:
        # No identifier directly after `function` (or after the output list):
        # the declaration is malformed, so record it rather than guess a name.
        return {"status": "invalid", "kind": "function", "text": stripped}
    name = name_match.group(1)
    tail = rest[name_match.end() :].lstrip()
    arguments = ""
    if tail.startswith("("):
        candidate = tail
        balance = 0
        for idx, ch in enumerate(candidate):
            if ch == "(":
                balance += 1
            elif ch == ")":
                balance -= 1
                if balance == 0:
                    arguments = candidate[: idx + 1]
                    break
    if not arguments:
        # A function header without a (possibly empty) argument list is not a
        # declaration we can name safely; skip it rather than invent one.
        return {"status": "invalid", "kind": "function", "text": stripped}
    signature = _normalize_signature(
        " ".join(
            part
            for part in (
                (f"[{', '.join(outputs)}] =" if len(outputs) > 1 else (f"{outputs[0]} =" if outputs else "")),
                name,
                arguments,
            )
            if part
        )
    )
    return {
        "status": "ok",
        "kind": "function",
        "name": name,
        "signature": signature,
        "outputs": outputs,
        "arguments": arguments,
    }


def _classdef_name(rest: str) -> str | None:
    """Extract a class name from the ``classdef`` remainder.

    Supports an optional attribute prefix such as ``classdef (Abstract) C < B``
    and a plain ``classdef C``. When the name cannot be isolated the function
    returns ``None`` so the caller records a diagnostic instead of inventing a
    symbol.
    """
    text = rest.strip()
    if not text:
        return None
    attributes = _ATTR_LIST.match(text)
    if attributes:
        # A leading parenthesised group is an attribute list, not the name.
        text = attributes.group(2).strip()
    match = re.match(r"([A-Za-z_][\w\u00a1-\uffff]*)", text)
    if not match:
        return None
    candidate = match.group(1)
    reserved = {"end", "properties", "methods", "events", "arguments"}
    if candidate.lower() in reserved:
        return None
    return candidate


def _fallback_extract(source_bytes: bytes, rel_path: str) -> tuple[list, list]:
    """Conservative lexical outline of one MATLAB source file.

    This is an outline approximation, not a full parser. ``end_line`` and
    ``parent_scope`` are always ``null`` because declaration extents and
    nesting cannot be established reliably without a real grammar; methods
    inside a ``classdef`` are recognised syntactically as functions but keep
    ``partial`` confidence and a null parent scope rather than asserting a
    precise class binding.
    """
    text = source_bytes.decode("utf-8", errors="replace")
    symbols: list[dict] = []
    diagnostics: list[dict] = []

    for start_row, _end_row, logical in _split_logical_lines(text):
        parsed = _fallback_parse_declaration(logical)
        if parsed is None:
            continue
        if parsed["status"] in ("invalid", "ambiguous"):
            diagnostics.append(
                {
                    "file": rel_path,
                    "line": start_row,
                    "code": f"declaration-{parsed['status']}",
                    "detail": (
                        f"{parsed['kind']} declaration at line {start_row} was "
                        "skipped as " + parsed["status"]
                    ),
                }
            )
            continue
        symbols.append(
            _make_symbol(
                file=rel_path,
                kind=parsed["kind"],
                name=parsed["name"],
                signature=parsed["signature"],
                start_line=start_row,
                end_line=None,
                parent_scope=None,
                extraction_confidence="syntactic" if parsed["kind"] == "class" else "partial",
            )
        )
    return symbols, diagnostics


# --------------------------------------------------------------------------
# extraction entry point
# --------------------------------------------------------------------------

def extract_symbols(source_bytes: bytes, relative_path: str, backend: str) -> dict:
    """Extract symbols from one MATLAB source file using the given backend."""
    if relative_path.lower().endswith(".lua"):
        raise OutlineError(f"refusing to feed Lua source to a MATLAB backend: {relative_path}")
    if backend == BACKEND_TREE_SITTER:
        symbols, diagnostics = _ts_extract(source_bytes, relative_path)
    elif backend == BACKEND_FALLBACK:
        symbols, diagnostics = _fallback_extract(source_bytes, relative_path)
    else:
        raise OutlineError(f"unknown extraction backend: {backend!r}")
    return {"symbols": symbols, "diagnostics": diagnostics}


# --------------------------------------------------------------------------
# catalogue assembly + validation
# --------------------------------------------------------------------------

_SYMBOL_KEYS = {
    "file",
    "language",
    "kind",
    "name",
    "signature",
    "start_line",
    "end_line",
    "parent_scope",
    "extraction_confidence",
}


def build_catalogue(root: str, source_roots, backend: str | None = None) -> dict:
    root_abs = os.path.abspath(root)
    chosen = backend or detect_backend()
    discovered = discover_sources(root_abs, source_roots)
    all_symbols: list[dict] = []
    all_diagnostics: list[dict] = []
    read_failed: list[str] = []

    for rel_path in discovered["files"]:
        abs_path = os.path.join(root_abs, rel_path)
        try:
            data = _read_bytes(abs_path)
        except OSError as exc:
            read_failed.append(rel_path)
            all_diagnostics.append(
                {
                    "file": rel_path,
                    "line": None,
                    "code": "read-error",
                    "detail": f"file could not be read: {type(exc).__name__}",
                }
            )
            continue
        result = extract_symbols(data, rel_path, chosen)
        all_symbols.extend(result["symbols"])
        all_diagnostics.extend(result["diagnostics"])

    all_symbols.sort(key=lambda s: (s["file"], s["start_line"], s["kind"], s["name"], s["signature"]))
    all_diagnostics.sort(
        key=lambda d: (d["file"] or "", d["line"] if d["line"] is not None else 0, d["code"], d["detail"])
    )
    truncated = len(all_diagnostics) > MAX_DIAGNOSTICS
    kept_diagnostics = all_diagnostics[:MAX_DIAGNOSTICS]
    if truncated:
        kept_diagnostics.append(
            {
                "file": None,
                "line": None,
                "code": "diagnostics-truncated",
                "detail": f"{len(all_diagnostics) - MAX_DIAGNOSTICS} further diagnostics omitted (bounded)",
            }
        )

    catalogue = {
        "schema_version": SCHEMA_VERSION,
        "generator_version": GENERATOR_VERSION,
        JSON_MARKER_KEY: JSON_MARKER_VALUE,
        "attribution": ATTRIBUTION,
        "attribution_note": (
            "Credit and configured workstream metadata only; it does not "
            "establish identity, verification, consent, authorization, "
            "execution evidence, or authority."
        ),
        "precision": PRECISION,
        "extraction_backend": chosen,
        "source_roots": sorted(set(sr.replace(os.sep, "/") for sr in source_roots)),
        "coverage": {
            "files_scanned": len(discovered["files"]),
            "files_with_symbols": len({s["file"] for s in all_symbols}),
            "symbol_count": len(all_symbols),
            "skipped_file_count": len(discovered["skipped"]) + len(read_failed),
            "skipped_files": discovered["skipped"],
            "unreadable_files": sorted(read_failed),
            "diagnostic_count": len(all_diagnostics),
            "diagnostics_truncated": truncated,
            "languages_supported": ["matlab"],
        },
        "interpretation_limits": list(INTERPRETATION_LIMITS),
        "diagnostics": kept_diagnostics,
        "symbols": all_symbols,
    }
    validate_catalogue(catalogue)
    return catalogue


def validate_catalogue(catalogue: dict) -> list:
    """Structural validation; raises OutlineError on contract violations."""
    problems: list[str] = []
    for key in (
        "schema_version",
        "generator_version",
        "source_roots",
        "extraction_backend",
        "precision",
        "coverage",
        "diagnostics",
        "symbols",
    ):
        if key not in catalogue:
            problems.append(f"missing top-level key: {key}")
    if problems:
        raise OutlineError("; ".join(problems))
    if catalogue["precision"] != PRECISION:
        raise OutlineError("precision must be syntactic_outline_only")

    seen_order: list[tuple] = []
    for position, symbol in enumerate(catalogue["symbols"]):
        missing = _SYMBOL_KEYS - set(symbol)
        extra = set(symbol) - _SYMBOL_KEYS
        if missing:
            problems.append(f"symbol #{position} missing keys: {sorted(missing)}")
        if extra:
            problems.append(f"symbol #{position} has opaque/extra keys: {sorted(extra)}")
        if symbol.get("language") != "matlab":
            problems.append(f"symbol #{position} language must be matlab")
        if symbol.get("kind") not in ("function", "class"):
            problems.append(f"symbol #{position} kind must be function or class")
        name = symbol.get("name")
        if not isinstance(name, str) or not name:
            problems.append(f"symbol #{position} name must be a non-empty string")
        file_value = symbol.get("file")
        if not isinstance(file_value, str) or not file_value:
            problems.append(f"symbol #{position} file must be a non-empty string")
        elif os.path.isabs(file_value) or ".." in file_value.split("/") or "\\" in file_value:
            problems.append(f"symbol #{position} file must be repository-relative POSIX: {file_value}")
        start = symbol.get("start_line")
        if not isinstance(start, int) or isinstance(start, bool) or start < 1:
            problems.append(f"symbol #{position} start_line must be a one-based integer")
        end = symbol.get("end_line")
        if end is not None and (not isinstance(end, int) or isinstance(end, bool) or end < 1):
            problems.append(f"symbol #{position} end_line must be an integer or null")
        if isinstance(end, int) and isinstance(start, int) and end < start:
            problems.append(f"symbol #{position} end_line precedes start_line")
        parent = symbol.get("parent_scope")
        if parent is not None and not isinstance(parent, str):
            problems.append(f"symbol #{position} parent_scope must be a string or null")
        if symbol.get("extraction_confidence") not in ("syntactic", "partial"):
            problems.append(f"symbol #{position} extraction_confidence must be syntactic or partial")
        if "\x00" in json.dumps(symbol):
            problems.append(f"symbol #{position} contains NUL")
        seen_order.append((file_value, start, symbol.get("kind"), name, symbol.get("signature")))

    ordered = sorted(seen_order, key=lambda item: (item[0], item[1], item[2], item[3], item[4]))
    if seen_order != ordered:
        problems.append("symbols are not in deterministic (file, start_line, kind, name, signature) order")

    for diag in catalogue["diagnostics"]:
        if set(diag) != {"file", "line", "code", "detail"}:
            problems.append(f"diagnostic has unexpected keys: {sorted(diag)}")
        detail = diag.get("detail", "")
        if len(detail) > DIAGNOSTIC_TEXT_LIMIT + 60:
            problems.append("diagnostic detail exceeds the bounded length")

    coverage = catalogue["coverage"]
    if coverage.get("symbol_count") != len(catalogue["symbols"]):
        problems.append("coverage.symbol_count disagrees with symbols length")

    serialized = json.dumps(catalogue, ensure_ascii=False, sort_keys=True)
    home = os.path.expanduser("~")
    cwd = os.getcwd()
    for offender in (home, cwd):
        if offender and offender != "/" and offender in serialized:
            problems.append(f"catalogue leaks machine-specific path: {offender}")
    if problems:
        raise OutlineError("; ".join(problems[:20]))
    return problems


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------

_PATH_SAFE = "/:@!$&'()*+,;=~"


def _url_encode_path(rel_path: str) -> str:
    return _url_quote(rel_path, safe=_PATH_SAFE)


def _escape_markdown_cell(text: str) -> str:
    protected = text.replace("`", "&#96;")
    escaped = re.sub(r"([\\`*_{}\[\]()<>|#!+\-])", r"\\\1", protected)
    escaped = escaped.replace("--", "\\-\\-")
    return escaped


def _escape_plain(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("[", "&#91;")
        .replace("]", "&#93;")
        .replace("|", "&#124;")
        .replace("`", "&#96;")
        .replace("*", "&#42;")
        .replace("_", "&#95;")
    )


def render_markdown(catalogue: dict) -> str:
    coverage = catalogue["coverage"]
    backend = catalogue["extraction_backend"]
    lines: list[str] = [
        "# MATLAB symbol catalogue",
        "",
        MARKDOWN_MARKER,
        f"Generator: `{catalogue['generator_version']}` | Schema: `{catalogue['schema_version']}` "
        f"| Backend: `{backend}` | Precision: `{catalogue['precision']}`",
        "",
        "> **This is a generated syntactic snapshot, not GitHub's native symbol outline "
        "or a precise reference index.**",
        "",
        "## Coverage",
        "",
        f"- Source roots: {', '.join('`' + r + '`' for r in catalogue['source_roots'])}",
        f"- Files scanned: {coverage['files_scanned']}",
        f"- Files with symbols: {coverage['files_with_symbols']}",
        f"- Symbols recorded: {coverage['symbol_count']}",
        f"- Skipped files: {coverage['skipped_file_count']}",
        f"- Diagnostics: {coverage['diagnostic_count']}"
        + (" (truncated)" if coverage.get("diagnostics_truncated") else ""),
        "",
        "## Backend and limitations",
        "",
        f"Backend `{backend}` is an outline approximation. "
        "`end_line` and `parent_scope` are shown as `null` wherever the backend "
        "cannot establish them. No properties, variable references, or method "
        "bindings are extracted, and no references are inferred from calls.",
        "",
    ]
    for limit in catalogue["interpretation_limits"]:
        lines.append(f"- {_escape_plain(limit)}")
    lines.append("")

    grouped: dict[str, list[dict]] = {}
    for symbol in catalogue["symbols"]:
        grouped.setdefault(symbol["file"], []).append(symbol)

    lines.append("## Symbols by source file")
    lines.append("")
    if not grouped:
        lines.append("_No MATLAB symbols were found under the selected source roots._")
        lines.append("")
    for rel_path in sorted(grouped):
        link_target = "../" + _url_encode_path(rel_path)
        lines.append(f"### [`{_escape_markdown_cell(rel_path)}`]({link_target})")
        lines.append("")
        lines.append("| Kind | Name | Signature | Line | Link | Confidence |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for symbol in grouped[rel_path]:
            anchor = f"{link_target}#L{symbol['start_line']}"
            lines.append(
                "| {kind} | {name} | {sig} | {line} | [L{line}]({anchor}) | {conf} |".format(
                    kind=symbol["kind"],
                    name=_escape_markdown_cell(symbol["name"]),
                    sig=_escape_markdown_cell(symbol["signature"] or "-"),
                    line=symbol["start_line"],
                    anchor=anchor,
                    conf=symbol["extraction_confidence"],
                )
            )
        lines.append("")

    if catalogue["diagnostics"]:
        lines.append("## Diagnostics")
        lines.append("")
        lines.append("| File | Line | Code | Detail |")
        lines.append("| --- | --- | --- | --- |")
        for diag in catalogue["diagnostics"]:
            lines.append(
                "| {file} | {line} | {code} | {detail} |".format(
                    file=_escape_markdown_cell(diag["file"] or "-"),
                    line=diag["line"] if diag["line"] is not None else "-",
                    code=_escape_markdown_cell(diag["code"]),
                    detail=_escape_markdown_cell(diag["detail"]),
                )
            )
        lines.append("")

    if coverage["skipped_files"]:
        lines.append("## Skipped files")
        lines.append("")
        for item in coverage["skipped_files"]:
            lines.append(f"- `{_escape_markdown_cell(item['path'])}` — {_escape_markdown_cell(item['reason'])}")
        lines.append("")

    lines.append("## Attribution")
    lines.append("")
    lines.append(f"Configured attribution: `{ATTRIBUTION}`")
    lines.append("")
    lines.append(_escape_plain(catalogue["attribution_note"]))
    lines.append("")
    return "\n".join(lines)


def _tag_field(text: str) -> str:
    cleaned = str(text)
    for char in ("\t", "\r", "\n", "\v", "\f", "\x00"):
        cleaned = cleaned.replace(char, " ")
    cleaned = cleaned.replace("\\", "\\\\")
    cleaned = cleaned.replace(";", "\\;")
    cleaned = cleaned.replace(",", "\\,")
    cleaned = cleaned.replace("\t", "\\t")
    return cleaned


def render_ctags(catalogue: dict) -> str:
    lines = [
        TAGS_MARKER,
        "!_TAG_FILE_SORTED\t0\t/0=unsorted, 1=sorted, 2=foldcase/",
        "!_TAG_FILE_PROCEDURE\t1\t/generated by matlab-outline; do not edit by hand/",
        "!_TAG_FILE_ENCODING\tutf-8\t//",
        "!_TAG_PROGRAM_NAME\tmatlab-outline\t//",
        f"!_TAG_PROGRAM_VERSION\t{GENERATOR_VERSION.split('/')[-1]}\t//",
        "!_TAG_TAGFILE_DIR_SCHEME\trepo-root-relative\t/"
        "paths are relative to the repository root; the consumer must join "
        "them against the checkout root before opening/",
        f"!_TAG_MATLAB_OUTLINE_SCHEMA\t{catalogue['schema_version']}\t//",
        f"!_TAG_MATLAB_OUTLINE_BACKEND\t{catalogue['extraction_backend']}\t//",
        f"!_TAG_MATLAB_OUTLINE_PRECISION\t{PRECISION}\t//",
        f"!_TAG_MATLAB_OUTLINE_ATTRIBUTION\t{ATTRIBUTION}\t/"
        "credit and configured metadata only; no identity or authority implied/",
        "",
    ]
    kind_map = {"function": "f", "class": "c"}
    for symbol in catalogue["symbols"]:
        name = _tag_field(symbol["name"])
        if not name or name.startswith("!"):
            continue
        fields = [
            name,
            _tag_field(symbol["file"]),
            f"{symbol['start_line']};\"",
        ]
        extras = [f"kind:{kind_map.get(symbol['kind'], 'f')}"]
        if symbol["kind"] == "function":
            extras.append("function")
        else:
            extras.append("class")
        extras.append(f"line:{symbol['start_line']}")
        extras.append(f"language:{symbol['language']}")
        extras.append(f"precision:{PRECISION}")
        extras.append(f"confidence:{symbol['extraction_confidence']}")
        extras.append(f"signature:{_tag_field(symbol['signature'])}")
        if symbol["end_line"] is not None:
            extras.append(f"end:{symbol['end_line']}")
        if symbol["parent_scope"] is not None:
            extras.append(f"scope:{_tag_field(symbol['parent_scope'])}")
        lines.append("\t".join(fields + extras))
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------
# output assembly, freshness checking, atomic writing
# --------------------------------------------------------------------------

def render_json(catalogue: dict) -> str:
    return json.dumps(catalogue, indent=2, ensure_ascii=False, sort_keys=True) + "\n"


def build_outputs(root: str, source_roots, backend: str | None = None) -> dict:
    """Build every artifact in memory (validated) before anything is written."""
    catalogue = build_catalogue(root, source_roots, backend=backend)
    outputs = {
        "docs/reference/symbols.json": render_json(catalogue).encode("utf-8"),
        "docs/reference/symbols.md": render_markdown(catalogue).encode("utf-8"),
        "docs/reference/matlab.tags": render_ctags(catalogue).encode("utf-8"),
    }
    return {"catalogue": catalogue, "outputs": outputs}


def _has_generator_marker(abs_path: str, rel_path: str) -> bool:
    try:
        head = _read_bytes(abs_path, limit=4096)
    except OSError:
        return False
    text = head.decode("utf-8", "replace")
    if rel_path.endswith(".json"):
        try:
            data = json.loads(text) if head.strip().endswith(b"}") or True else {}
        except Exception:
            data = None
        if isinstance(data, dict):
            return data.get(JSON_MARKER_KEY) == JSON_MARKER_VALUE
        return JSON_MARKER_VALUE in text
    if rel_path.endswith(".md"):
        return MARKDOWN_MARKER in text
    if rel_path.endswith(".tags"):
        return "!_TAG_MATLAB_OUTLINE_" in text
    return False


def _atomic_write(abs_path: str, payload: bytes, rel_path: str, force: bool) -> str:
    directory = os.path.dirname(abs_path)
    os.makedirs(directory, exist_ok=True)
    if os.path.exists(abs_path) and not force:
        if not _has_generator_marker(abs_path, rel_path):
            raise OutlineError(
                f"refusing to overwrite unrelated existing file without a generator marker: {rel_path}"
            )
    if os.path.islink(abs_path):
        raise OutlineError(f"refusing to write through a symlink: {rel_path}")
    handle, tmp_name = tempfile.mkstemp(prefix=f".{os.path.basename(abs_path)}.", dir=directory)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp_name, abs_path)
    except Exception:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)
        raise
    return rel_path


def write_outputs(root: str, outputs: dict, force: bool = False) -> list:
    root_abs = os.path.abspath(root)
    written = []
    for rel_path in OUTPUT_RELPATHS:
        if rel_path not in outputs:
            raise OutlineError(f"expected output missing in memory: {rel_path}")
        abs_path = os.path.join(root_abs, rel_path)
        if not _is_within(abs_path, root_abs):
            raise OutlineError(f"output path escapes repository root: {rel_path}")
        payload = outputs[rel_path]
        try:
            written.append(_atomic_write(abs_path, payload, rel_path, force))
        except OutlineError:
            raise
        except OSError as exc:
            raise OutlineError(f"I/O failure writing {rel_path}: {exc}") from exc
    return written


def check_outputs(root: str, expected_outputs: dict) -> list:
    """Compare committed bytes with freshly generated bytes. Never writes."""
    root_abs = os.path.abspath(root)
    stale: list[str] = []
    for rel_path in OUTPUT_RELPATHS:
        abs_path = os.path.join(root_abs, rel_path)
        if not _is_within(abs_path, root_abs):
            raise OutlineError(f"output path escapes repository root: {rel_path}")
        if not os.path.isfile(abs_path):
            stale.append(f"missing: {rel_path}")
            continue
        try:
            current = _read_bytes(abs_path)
        except OSError as exc:
            stale.append(f"unreadable: {rel_path} ({type(exc).__name__})")
            continue
        if current != expected_outputs[rel_path]:
            stale.append(f"stale: {rel_path}")
    return stale


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="matlab_outline.py",
        description=(
            "Generate a bounded, syntactic-only MATLAB symbol catalogue "
            "(JSON + Markdown + ctags). Additive navigation aid; not GitHub's "
            "native outline or a reference index."
        ),
    )
    parser.add_argument("--root", default=".", help="repository root (default: .)")
    parser.add_argument(
        "--source-root",
        action="append",
        dest="source_roots",
        metavar="PATH",
        help="approved MATLAB source root, repeatable (default: matlab)",
    )
    parser.add_argument(
        "--backend",
        choices=[BACKEND_TREE_SITTER, BACKEND_FALLBACK, "auto"],
        default="auto",
        help=(
            "pin the extraction backend so generation and checking agree "
            "(default: auto-detect once, then use it for both)"
        ),
    )
    parser.add_argument("--write", action="store_true", help="write the three owned artifacts")
    parser.add_argument("--check", action="store_true", help="verify committed artifacts are current")
    parser.add_argument(
        "--force",
        action="store_true",
        help="allow --write to replace an existing file lacking a generator marker",
    )
    parser.add_argument("--json-summary", action="store_true", help="print a bounded run summary as JSON")
    return parser


def main(argv=None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.write and args.check:
        print("error: choose exactly one of --write or --check", file=sys.stderr)
        return 2
    if not args.write and not args.check:
        print("error: exactly one of --write or --check is required", file=sys.stderr)
        return 2

    root = args.root
    if not os.path.isdir(root):
        print(f"error: repository root is not a directory: {root}", file=sys.stderr)
        return 2
    root_abs = os.path.abspath(root)
    for rel in args.source_roots or DEFAULT_SOURCE_ROOTS:
        norm = os.path.normpath(str(rel)).replace("\\", "/")
        if norm.startswith("..") or os.path.isabs(norm):
            print(f"error: source root escapes repository root: {rel}", file=sys.stderr)
            return 2

    backend = args.backend if args.backend != "auto" else detect_backend()

    try:
        built = build_outputs(root_abs, args.source_roots or list(DEFAULT_SOURCE_ROOTS), backend=backend)
    except OutlineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    except Exception as exc:  # defensive: report, never trace-dump secrets
        print(f"error: unexpected generation failure: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 3

    catalogue = built["catalogue"]
    coverage = catalogue["coverage"]

    if args.check:
        stale = check_outputs(root_abs, built["outputs"])
        if args.json_summary:
            print(
                json.dumps(
                    {
                        "mode": "check",
                        "backend": backend,
                        "status": "stale" if stale else "current",
                        "stale": stale,
                        "symbol_count": coverage["symbol_count"],
                        "files_scanned": coverage["files_scanned"],
                        "skipped_file_count": coverage["skipped_file_count"],
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
        if stale:
            for item in stale:
                print(f"out-of-date: {item}", file=sys.stderr)
            print(
                "freshness check failed; run with --write to regenerate the owned artifacts",
                file=sys.stderr,
            )
            return 1
        print("outputs are current")
        return 0

    try:
        written = write_outputs(root_abs, built["outputs"], force=args.force)
    except OutlineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3
    except OSError as exc:
        print(f"error: I/O failure: {exc}", file=sys.stderr)
        return 3

    if args.json_summary:
        print(
            json.dumps(
                {
                    "mode": "write",
                    "backend": backend,
                    "written": written,
                    "symbol_count": coverage["symbol_count"],
                    "files_scanned": coverage["files_scanned"],
                    "skipped_file_count": coverage["skipped_file_count"],
                    "diagnostic_count": coverage["diagnostic_count"],
                },
                indent=2,
                sort_keys=True,
            )
        )
    else:
        print(
            "wrote {count} artifact(s); backend={backend}; symbols={symbols}; "
            "files_scanned={scanned}; skipped={skipped}; diagnostics={diags}".format(
                count=len(written),
                backend=backend,
                symbols=coverage["symbol_count"],
                scanned=coverage["files_scanned"],
                skipped=coverage["skipped_file_count"],
                diags=coverage["diagnostic_count"],
            )
        )
    print(
        "note: each artifact was replaced independently (per-file atomic rename); "
        "this is not a multi-file transaction."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
