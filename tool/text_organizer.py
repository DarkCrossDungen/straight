"""Offline, conservative text organization for dictated text."""

from __future__ import annotations

import argparse
import re
import sys
from typing import Literal

CleanupLevel = Literal["none", "light", "medium", "high"]

_FILLERS = re.compile(r"\b(?:um|uh|er|ah|hmm|mm)\b", re.IGNORECASE)
_REPEATED_WORD = re.compile(r"\b([\w']+)(?:[\s,]+\1)+\b", re.IGNORECASE)
_BACKTRACK = re.compile(
    r"\b(?:scratch that|ignore that|delete that|never mind|start over|"
    r"no,? I mean|what I meant was|let me rephrase)\b",
    re.IGNORECASE,
)
_TOPIC_TRANSITION = re.compile(
    r"\s*([.!?])\s*((?:on another note|moving on|regarding|as for|"
    r"next topic|separately|additionally)\b)",
    re.IGNORECASE,
)
_ORDINAL = re.compile(
    r"\b(first|firstly|second|secondly|third|thirdly|fourth|fourthly|"
    r"finally|lastly)[,:]?\s+",
    re.IGNORECASE,
)
_EXPLICIT_BULLET = re.compile(r"\b(?:new |next )?bullet(?: point)?\b", re.IGNORECASE)
_SPOKEN_BREAKS = re.compile(
    r"\b(new paragraph|new line)\b", re.IGNORECASE
)


def organize(text: str, level: CleanupLevel = "medium") -> str:
    """Format explicit dictation cues without changing intended meaning."""
    if level not in {"none", "light", "medium", "high"}:
        raise ValueError(f"Unsupported cleanup level: {level}")
    if level == "none" or not text:
        return text

    result = text.strip()
    result = _apply_backtracks(result)
    result = _format_spoken_breaks(result)
    result = _format_lists(result)
    result = _TOPIC_TRANSITION.sub(r"\1\n\n\2", result)

    if level in {"light", "medium", "high"}:
        result = _FILLERS.sub("", result)
        result = _normalize_spacing(result)
        result = _fix_punctuation(result)
        result = _capitalize_sentences(result)

    if level in {"medium", "high"}:
        result = _REPEATED_WORD.sub(r"\1", result)
        result = _normalize_spacing(result)

    return result.strip()


def _apply_backtracks(text: str) -> str:
    result = text
    while match := _BACKTRACK.search(result):
        before = result[: match.start()].rstrip()
        after = result[match.end() :].strip(" ,;:-")
        sentence_boundary = max(before.rfind("."), before.rfind("!"), before.rfind("?"))
        kept = before[: sentence_boundary + 1].rstrip() if sentence_boundary >= 0 else ""
        result = " ".join(part for part in (kept, after) if part)
    return result


def _format_spoken_breaks(text: str) -> str:
    result = _SPOKEN_BREAKS.sub(
        lambda match: "\n\n" if match.group(1).lower() == "new paragraph" else "\n",
        text,
    )
    return re.sub(r"[ \t]*\n[ \t]*", "\n", result)


def _format_lists(text: str) -> str:
    matches = list(_ORDINAL.finditer(text))
    if len(matches) >= 2:
        prefix = text[: matches[0].start()].strip()
        items = []
        for index, match in enumerate(matches):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            item = text[match.end() : end].strip(" ,;:\n")
            if item:
                items.append(f"{len(items) + 1}. {item}")
        if len(items) >= 2:
            return "\n".join(part for part in (prefix, "\n".join(items)) if part)

    if _EXPLICIT_BULLET.search(text):
        parts = _EXPLICIT_BULLET.split(text)
        prefix = parts[0].strip()
        items = [part.strip(" ,;:\n") for part in parts[1:] if part.strip(" ,;:\n")]
        if items:
            return "\n".join(
                part for part in (prefix, "\n".join(f"• {item}" for item in items)) if part
            )
    return text


def _normalize_spacing(text: str) -> str:
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"[ \t]*\n[ \t]*", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def _fix_punctuation(text: str) -> str:
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"([,.;:!?])([^\s\n])", r"\1 \2", text)
    text = re.sub(r"([.!?])(?:\s*[.!?])+", r"\1", text)
    text = re.sub(r"\s+([)\]}])", r"\1", text)
    text = re.sub(r"([(\[{])\s+", r"\1", text)

    lines = text.split("\n")
    return "\n".join(line.rstrip() for line in lines)


def _capitalize_sentences(text: str) -> str:
    return re.sub(
        r"(^|[.!?]\s+)([a-z])",
        lambda match: match.group(1) + match.group(2).upper(),
        text,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Organize dictated text offline")
    parser.add_argument("--level", choices=("none", "light", "medium", "high"), default="medium")
    parser.add_argument("text", nargs="*", help="Text to organize; reads stdin when omitted")
    args = parser.parse_args()
    source = " ".join(args.text) if args.text else sys.stdin.read()
    print(organize(source, args.level))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
