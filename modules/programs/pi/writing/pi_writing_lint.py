import argparse
import json
import re
import sys
from contextlib import redirect_stderr
from dataclasses import asdict, dataclass
from pathlib import Path

WORD_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9'/-]*")
SENTENCE_BREAK = re.compile(r"(?<=[.!?])\s+(?=[A-Z0-9\"'])")
CONTRACTION = re.compile(
    r"\b(?:ain't|aren't|can't|couldn't|didn't|doesn't|don't|hadn't|"
    r"hasn't|haven't|he'd|he'll|he's|i'd|i'll|i'm|i've|isn't|it'd|"
    r"it'll|it's|let's|mightn't|mustn't|shan't|she'd|she'll|she's|"
    r"shouldn't|that's|there's|they'd|they'll|they're|they've|wasn't|"
    r"we'd|we'll|we're|we've|weren't|what's|where's|who's|won't|"
    r"wouldn't|you'd|you'll|you're|you've|\w+n't)\b",
    re.IGNORECASE,
)
PASSIVE = re.compile(
    r"\b(?:am|is|are|was|were|be|been|being)\s+(?:\w+ed|done|made|"
    r"sent|read|built|kept|held|set|put|run|written|shown|given|taken|"
    r"found|seen|known|thrown|drawn)\b",
    re.IGNORECASE,
)
PROGRESSIVE = re.compile(
    r"\b(?:am|is|are|was|were|be|been|being)\s+\w+ing\b", re.IGNORECASE
)
NOMINALIZATION = re.compile(
    r"\b(?:perform(?:s|ed)?|conduct(?:s|ed)?|provide(?:s|d)?|carry out|"
    r"carries out|make use of|makes use of)\b|"
    r"\b\w{4,}(?:tion|ment|ance|ence)\s+of\b",
    re.IGNORECASE,
)
VAGUE = re.compile(
    r"\b(?:seamless|seamlessly|robust|powerful|cutting-edge|effortless|"
    r"effortlessly|world-class|next-generation|revolutionary|elegant|"
    r"delightful|turnkey|best-in-class|state-of-the-art|game-changing|"
    r"battle-tested|enterprise-grade|supercharge|unlock|unleash|empower|"
    r"comprehensive|various|numerous|solution)\b",
    re.IGNORECASE,
)
LIST_ITEM = re.compile(r"^\s*(?:(?P<number>\d+)[.)]|[-*+])\s+(?P<text>.+)$")
HEADING = re.compile(r"^\s*#{1,6}\s+(?P<text>.+)$")
FRONTMATTER_VALUE = re.compile(r"^\s*[A-Za-z0-9_-]+:\s*(?P<value>.+?)\s*$")
TABLE_SEPARATOR = re.compile(r"^:?-{3,}:?$")
LINK = re.compile(r"\[([^]]+)]\([^)]*\)")
INLINE_CODE = re.compile(r"`+[^`]*`+")
ABBREVIATIONS = ("e.g.", "i.e.", "Dr.", "Mr.", "Mrs.", "Ms.", "vs.")
PROCEDURE_VERBS = {
    "add",
    "build",
    "call",
    "check",
    "close",
    "copy",
    "create",
    "delete",
    "edit",
    "install",
    "load",
    "move",
    "open",
    "read",
    "remove",
    "rename",
    "restart",
    "run",
    "save",
    "select",
    "send",
    "set",
    "start",
    "stop",
    "update",
    "use",
    "verify",
    "write",
}
SUBJECT_STARTS = {
    "a",
    "an",
    "he",
    "i",
    "it",
    "she",
    "that",
    "the",
    "these",
    "they",
    "this",
    "those",
    "we",
    "you",
}

SUGGESTIONS = {
    "sentence-length": "Split the sentence without deleting necessary detail.",
    "contraction": "Write the complete form.",
    "semicolon": "Write two sentences.",
    "em-dash": "Use a period, comma, or parentheses.",
    "paragraph-length": "Split the paragraph by topic.",
    "procedure-actions": "Put each action in a separate numbered step.",
    "passive-voice": (
        "Name the actor and use active voice when the actor is known."
    ),
    "progressive-verb": "Use a simple verb tense.",
    "nominalized-action": "Express the action with a verb.",
    "vague-language": "Name the concrete behavior and effect.",
}


@dataclass(frozen=True)
class Diagnostic:
    source: str
    line: int
    rule: str
    message: str
    suggestion: str
    heuristic: bool = False

    def as_dict(self):
        return asdict(self)


@dataclass(frozen=True)
class Block:
    line: int
    text: str
    numbered: bool = False


def clean_markdown(text):
    text = LINK.sub(r"\1", text)
    return INLINE_CODE.sub("", text)


def extract_blocks(text, markdown):
    lines = text.splitlines()
    blocks = []
    paragraph = []
    paragraph_line = 1
    in_fence = False
    in_frontmatter = markdown and bool(lines) and lines[0].strip() == "---"

    def flush():
        nonlocal paragraph
        if paragraph:
            blocks.append(Block(paragraph_line, " ".join(paragraph)))
            paragraph = []

    for index, raw in enumerate(lines, 1):
        stripped = raw.strip()
        if in_frontmatter:
            if index > 1 and stripped == "---":
                in_frontmatter = False
                continue
            match = FRONTMATTER_VALUE.match(raw)
            if match:
                value = match.group("value").strip().strip("\"'")
                if value:
                    blocks.append(Block(index, clean_markdown(value)))
            continue
        if markdown and (
            stripped.startswith("```") or stripped.startswith("~~~")
        ):
            flush()
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if markdown and stripped.startswith(">"):
            flush()
            continue
        if not stripped:
            flush()
            continue
        if markdown and stripped.startswith("|") and stripped.endswith("|"):
            flush()
            cells = [cell.strip() for cell in stripped[1:-1].split("|")]
            for cell in cells:
                if cell and not TABLE_SEPARATOR.fullmatch(cell):
                    blocks.append(Block(index, clean_markdown(cell)))
            continue
        item = LIST_ITEM.match(raw)
        if item:
            flush()
            blocks.append(
                Block(
                    index,
                    clean_markdown(item.group("text")),
                    item.group("number") is not None,
                )
            )
            continue
        if markdown:
            heading = HEADING.match(raw)
            if heading:
                flush()
                blocks.append(
                    Block(index, clean_markdown(heading.group("text")))
                )
                continue
        if not paragraph:
            paragraph_line = index
        paragraph.append(clean_markdown(stripped))
    flush()
    return blocks


def split_sentences(text):
    protected = text
    tokens = {}
    for index, abbreviation in enumerate(ABBREVIATIONS):
        token = f"__ABBR_{index}__"
        if abbreviation in protected:
            protected = protected.replace(abbreviation, token)
            tokens[token] = abbreviation
    sentences = SENTENCE_BREAK.split(protected)
    return [
        _restore_tokens(sentence.strip(), tokens)
        for sentence in sentences
        if sentence.strip()
    ]


def _restore_tokens(text, tokens):
    for token, value in tokens.items():
        text = text.replace(token, value)
    return text


def word_count(text):
    return len(WORD_PATTERN.findall(text))


def is_imperative(text):
    words = WORD_PATTERN.findall(text)
    if not words:
        return False
    first = words[0].lower()
    return first not in SUBJECT_STARTS and not first.endswith(("ed", "ing"))


def make_diagnostic(source, line, rule, message, heuristic=False):
    return Diagnostic(
        source, line, rule, message, SUGGESTIONS[rule], heuristic
    )


def has_multiple_procedure_actions(text):
    pattern = re.compile(r"\b(?:and|then)\s+([A-Za-z]+)\b", re.IGNORECASE)
    return any(
        match.group(1).lower() in PROCEDURE_VERBS
        for match in pattern.finditer(text)
    )


def lint_text(text, source="<stdin>", markdown=True):
    diagnostics = []
    for block in extract_blocks(text, markdown):
        sentences = split_sentences(block.text)
        limit = 20 if block.numbered and is_imperative(block.text) else 25
        for sentence in sentences:
            count = word_count(sentence)
            if count > limit:
                diagnostics.append(
                    make_diagnostic(
                        source,
                        block.line,
                        "sentence-length",
                        f"Sentence has {count} words; the limit is {limit}.",
                    )
                )
        if len(sentences) > 6:
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "paragraph-length",
                    f"Paragraph has {len(sentences)} sentences; "
                    "the limit is 6.",
                )
            )
        if CONTRACTION.search(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "contraction",
                    "Text contains a contraction.",
                )
            )
        if ";" in block.text:
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "semicolon",
                    "Text contains a semicolon.",
                )
            )
        if "—" in block.text:
            diagnostics.append(
                make_diagnostic(
                    source, block.line, "em-dash", "Text contains an em dash."
                )
            )
        if block.numbered and has_multiple_procedure_actions(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "procedure-actions",
                    "Numbered step appears to contain more than one action.",
                )
            )
        if PASSIVE.search(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "passive-voice",
                    "Text appears to use passive voice.",
                    True,
                )
            )
        if PROGRESSIVE.search(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "progressive-verb",
                    "Text appears to use a progressive main verb.",
                    True,
                )
            )
        if NOMINALIZATION.search(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "nominalized-action",
                    "Text appears to express an action as a noun phrase.",
                    True,
                )
            )
        if VAGUE.search(block.text):
            diagnostics.append(
                make_diagnostic(
                    source,
                    block.line,
                    "vague-language",
                    "Text contains vague or promotional language.",
                    True,
                )
            )
    return sorted(
        diagnostics, key=lambda item: (item.source, item.line, item.rule)
    )


def format_text(diagnostics):
    lines = []
    for item in diagnostics:
        marker = " [candidate]" if item.heuristic else ""
        lines.append(
            f"{item.source}:{item.line}: {item.rule}{marker}: "
            f"{item.message} {item.suggestion}"
        )
    return "\n".join(lines) + ("\n" if lines else "")


def main(argv=None, stdin=None, stdout=None, stderr=None):
    stdin = stdin or sys.stdin
    stdout = stdout or sys.stdout
    stderr = stderr or sys.stderr
    parser = argparse.ArgumentParser(prog="pi-writing-lint")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("files", nargs="*")
    try:
        with redirect_stderr(stderr):
            args = parser.parse_args(argv)
    except SystemExit as error:
        return int(error.code)

    diagnostics = []
    if args.files:
        for filename in args.files:
            path = Path(filename)
            if path.suffix.lower() not in {".md", ".markdown", ".txt"}:
                stderr.write(
                    f"pi-writing-lint: unsupported file type: {filename}\n"
                )
                return 2
            try:
                text = path.read_text()
            except OSError as error:
                stderr.write(
                    f"pi-writing-lint: cannot read {filename}: {error}\n"
                )
                return 2
            diagnostics.extend(
                lint_text(text, str(path), path.suffix.lower() != ".txt")
            )
    else:
        diagnostics.extend(lint_text(stdin.read()))

    diagnostics.sort(key=lambda item: (item.source, item.line, item.rule))
    if args.json_output:
        json.dump([item.as_dict() for item in diagnostics], stdout, indent=2)
        stdout.write("\n")
    else:
        stdout.write(format_text(diagnostics))
    return 1 if diagnostics else 0


if __name__ == "__main__":
    raise SystemExit(main())
