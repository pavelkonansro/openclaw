import unittest
from pathlib import Path


class PipelineReportTests(unittest.TestCase):
    REPORT = Path("pipeline_report_2026-03-04T20-50-UTC.txt")

    def test_report_file_exists(self):
        self.assertTrue(self.REPORT.exists(), f"Expected report file {self.REPORT} to exist")

    def test_report_has_header_and_blocked_status(self):
        text = self.REPORT.read_text(encoding="utf-8")
        self.assertIn("Pipeline test report", text, "Report header missing")
        # The runner earlier reported a BLOCKED status for missing repo
        self.assertTrue("Status: BLOCKED" in text or "BLOCKED" in text, "Expected 'BLOCKED' status in report")

    def test_report_contains_recommendation(self):
        text = self.REPORT.read_text(encoding="utf-8")
        lowered = text.lower()
        self.assertTrue(
            "re-run" in lowered or "clone the repository" in lowered or "re-run the pipeline" in lowered,
            "Expected recommended next steps in report",
        )


if __name__ == "__main__":
    unittest.main()
