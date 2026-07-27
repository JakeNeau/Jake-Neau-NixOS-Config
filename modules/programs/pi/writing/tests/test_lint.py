import json
import sys
import tempfile
import unittest
from io import StringIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from pi_writing_lint import lint_text, main

CLEAN = "The parser reads the file.\n"

DETERMINISTIC = {
    "sentence-length": (
        "The parser reads every configured source file and then combines all discovered "
        "records before it writes the complete result to the selected output file for later use.\n"
    ),
    "contraction": "The parser can't read the file.\n",
    "semicolon": "Read the file; write the result.\n",
    "em-dash": "Read the file—then write the result.\n",
    "paragraph-length": "One. Two. Three. Four. Five. Six. Seven.\n",
    "procedure-actions": "1. Read the file and write the result.\n",
}

HEURISTIC = {
    "passive-voice": "The file is read by the parser.\n",
    "progressive-verb": "The parser is reading the file.\n",
    "nominalized-action": "Perform an analysis of the file.\n",
    "vague-language": "This robust solution seamlessly improves the workflow.\n",
}


class RuleTests(unittest.TestCase):
    def test_clean_prose_has_no_diagnostics(self):
        self.assertEqual(lint_text(CLEAN), [])

    def test_deterministic_rules(self):
        for rule, text in DETERMINISTIC.items():
            with self.subTest(rule=rule):
                diagnostics = lint_text(text)
                self.assertIn(
                    rule, {diagnostic.rule for diagnostic in diagnostics}
                )
                self.assertFalse(
                    next(
                        item for item in diagnostics if item.rule == rule
                    ).heuristic
                )

    def test_heuristic_rules(self):
        for rule, text in HEURISTIC.items():
            with self.subTest(rule=rule):
                diagnostics = lint_text(text)
                diagnostic = next(
                    item for item in diagnostics if item.rule == rule
                )
                self.assertTrue(diagnostic.heuristic)

    def test_possessive_apostrophe_is_not_a_contraction(self):
        diagnostics = lint_text("The parser's output contains the record.\n")
        self.assertNotIn("contraction", {item.rule for item in diagnostics})

    def test_numbered_descriptive_item_uses_descriptive_limit(self):
        text = "1. The parser stores each valid record in the output file for use by the next command in the process.\n"
        self.assertNotIn(
            "sentence-length", {item.rule for item in lint_text(text)}
        )

    def test_compound_object_is_one_procedure_action(self):
        text = "1. Identify what the reader knows and needs.\n"
        self.assertNotIn(
            "procedure-actions", {item.rule for item in lint_text(text)}
        )

    def test_two_verbs_are_two_procedure_actions(self):
        text = "1. Read the file and write the result.\n"
        self.assertIn(
            "procedure-actions", {item.rule for item in lint_text(text)}
        )

    def test_plain_text_numbered_list_keeps_procedure_rules(self):
        text = "1. Read the file and write the result.\n"
        self.assertIn(
            "procedure-actions",
            {item.rule for item in lint_text(text, markdown=False)},
        )


class MarkdownTests(unittest.TestCase):
    def test_protected_markdown_has_no_diagnostics(self):
        text = """> The parser can't read this quotation.

```text
The parser can't read this code.
```

Use `can't;—` as the exact value.

Read the [reference](https://example.test/can't;—) label.
"""
        self.assertEqual(lint_text(text), [])

    def test_frontmatter_scalar_is_checked(self):
        text = "---\ndescription: The parser can't read the file.\nname: example\n---\n"
        diagnostic = next(
            item for item in lint_text(text) if item.rule == "contraction"
        )
        self.assertEqual(diagnostic.line, 2)

    def test_line_number_survives_protected_regions(self):
        text = """# Title

```text
The parser can't read this code.
```

The parser can't read the file.
"""
        diagnostic = next(
            item for item in lint_text(text) if item.rule == "contraction"
        )
        self.assertEqual(diagnostic.line, 7)

    def test_wrapped_paragraph_is_one_sentence(self):
        text = (
            "The parser reads every configured source file and combines all discovered records\n"
            "before it writes the complete result to the selected output file for later use.\n"
        )
        self.assertIn(
            "sentence-length", {item.rule for item in lint_text(text)}
        )

    def test_table_cells_are_separate_prose_blocks(self):
        text = "| Artifact | Structure |\n|---|---|\n| Reply | Answer and evidence. |\n"
        self.assertEqual(lint_text(text), [])

    def test_table_cell_reports_its_source_line(self):
        text = "| Rule | Text |\n|---|---|\n| Example | The parser can't read the file. |\n"
        diagnostic = next(
            item for item in lint_text(text) if item.rule == "contraction"
        )
        self.assertEqual(diagnostic.line, 3)


class CommandTests(unittest.TestCase):
    def run_main(self, argv, input_text=""):
        stdout = StringIO()
        stderr = StringIO()
        code = main(
            argv, stdin=StringIO(input_text), stdout=stdout, stderr=stderr
        )
        return code, stdout.getvalue(), stderr.getvalue()

    def test_standard_input_exit_codes(self):
        self.assertEqual(self.run_main([], CLEAN)[0], 0)
        self.assertEqual(self.run_main([], DETERMINISTIC["semicolon"])[0], 1)

    def test_json_output(self):
        code, output, error = self.run_main(
            ["--json"], DETERMINISTIC["semicolon"]
        )
        self.assertEqual(code, 1)
        self.assertEqual(error, "")
        payload = json.loads(output)
        self.assertEqual(payload[0]["rule"], "semicolon")
        self.assertEqual(payload[0]["source"], "<stdin>")

    def test_file_input(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "example.md"
            path.write_text(DETERMINISTIC["semicolon"])
            code, output, error = self.run_main([str(path)])
        self.assertEqual(code, 1)
        self.assertIn(f"{path}:1", output)
        self.assertEqual(error, "")

    def test_unsupported_suffix_is_input_error(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "example.rst"
            path.write_text(CLEAN)
            code, output, error = self.run_main([str(path)])
        self.assertEqual(code, 2)
        self.assertEqual(output, "")
        self.assertIn("unsupported file type", error)

    def test_missing_file_is_input_error(self):
        code, output, error = self.run_main(["missing.md"])
        self.assertEqual(code, 2)
        self.assertEqual(output, "")
        self.assertIn("cannot read", error)

    def test_usage_error_uses_injected_error_stream(self):
        code, output, error = self.run_main(["--unknown"])
        self.assertEqual(code, 2)
        self.assertEqual(output, "")
        self.assertIn("unrecognized arguments", error)


if __name__ == "__main__":
    unittest.main()
