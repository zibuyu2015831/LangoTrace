#!/usr/bin/env python3
"""Contract tests for scripts/verify.sh."""

from __future__ import annotations

from pathlib import Path
import unittest


SCRIPT_PATH = Path(__file__).resolve().parents[2] / "scripts" / "verify.sh"


class VerifyScriptContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.script = SCRIPT_PATH.read_text(encoding="utf-8")

    def test_runs_document_structure_and_patch_format_checks(self) -> None:
        self.assertIn("scripts/check-docs.sh", self.script)
        self.assertIn("git diff --check", self.script)

    def test_ui_package_test_is_not_piped_to_dev_null(self) -> None:
        self.assertIn("swift test --package-path Packages/LangoTraceUI", self.script)
        self.assertNotIn("tee /dev/null", self.script)

    def test_keeps_core_full_verification_gates(self) -> None:
        required_patterns = [
            "xcodegen generate",
            "xcodebuild -list -project LangoTrace.xcodeproj",
            "swift test --package-path Packages/LangoTraceCore",
            "swift test --package-path Packages/LangoTraceData",
            "swift test --package-path Packages/LangoTraceAI",
            "swift test --package-path Packages/LangoTraceSpeech",
            "swift test --package-path Packages/LangoTraceSync",
            "python3 -m unittest discover -s Tests/Tooling -p 'test_*.py'",
            "xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPhone 17' build",
            "xcodebuild -scheme LangoTrace-iOS -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build",
            "xcodebuild -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' build",
            "xcodebuild test -scheme LangoTrace-macOS -destination 'platform=macOS,arch=arm64' -only-testing:LangoTraceAppTests",
            "swiftlint",
            "swiftformat --lint . --exclude .build,build,DerivedData,LangoTrace.xcodeproj",
            "git status --short",
        ]

        for pattern in required_patterns:
            with self.subTest(pattern=pattern):
                self.assertIn(pattern, self.script)


if __name__ == "__main__":
    unittest.main()
