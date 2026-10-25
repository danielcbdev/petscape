"""Release boundary tests; no original art, remote writes or paid credentials."""

import importlib.util
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "release.py"


class ReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SCRIPT.exists():
            raise AssertionError("release implementation is missing")
        spec = importlib.util.spec_from_file_location("release", SCRIPT)
        cls.release = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.release)

    def test_versions_reject_unsafe_or_noncanonical_inputs(self):
        for version in ["v1.0.0", "01.0.0", "1.0", "1.0.0-beta", "1.0.0\n", "$(id)", "../1.0.0"]:
            with self.subTest(version=version), self.assertRaises(ValueError):
                self.release.validate_inputs(version, "2")
        for build in ["0", "01", "-1", "1.2", "2\n", "1000000000"]:
            with self.subTest(build=build), self.assertRaises(ValueError):
                self.release.validate_inputs("1.0.0", build)
        self.release.validate_inputs("1.0.0", "2")

    def test_notes_require_a_nonempty_changelog_section(self):
        self.assertIn("New pets", self.release.release_notes("## [Unreleased]\n\n### Added\n- New pets\n", "1.0.0"))
        self.assertIn("Fixed", self.release.release_notes("## [1.0.0] - 2026-10-25\n- Fixed\n", "1.0.0"))
        for content in ["", "## [Unreleased]\n", "## [0.1.0]\n- Old\n"]:
            with self.assertRaises(ValueError):
                self.release.release_notes(content, "1.0.0")

    def test_candidate_notes_exclude_historical_nonversion_sections(self):
        notes = self.release.release_notes("## [Unreleased]\n- New\n\n## MVP history\n- Old\n", "1.0.0")
        self.assertIn("New", notes)
        self.assertNotIn("Old", notes)

    def test_checksum_detects_corruption_missing_and_extra_files(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "payload").write_bytes(b"original")
            self.release.write_inventory(root)
            self.release.verify_inventory(root)
            (root / "payload").write_bytes(b"changed")
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root)
            (root / "payload").write_bytes(b"original")
            (root / "extra").write_bytes(b"extra")
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root)
            (root / "extra").unlink()
            (root / "payload").unlink()
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root)

    def test_missing_or_tampered_character_resource_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "source"
            target = root / "target"
            for path in [source, target]:
                (path / "cat").mkdir(parents=True)
                (path / "cat/character.json").write_text('{"id":"cat","image":"frame.png"}')
                (path / "cat/frame.png").write_bytes(b"png-fixture")
            self.release.verify_characters(source, target)
            (target / "cat/frame.png").write_bytes(b"changed")
            with self.assertRaises(ValueError):
                self.release.verify_characters(source, target)
            (target / "cat/frame.png").unlink()
            with self.assertRaises(ValueError):
                self.release.verify_characters(source, target)

    def test_character_path_escape_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "cat").mkdir()
            (root / "cat/character.json").write_text('{"image":"../outside.png"}')
            with self.assertRaises(ValueError):
                self.release.verify_characters(root, root)

    def test_universal_architecture_requires_both_and_only_expected_slices(self):
        self.release.validate_architectures("x86_64 arm64", "universal")
        self.release.validate_architectures("arm64", "arm64")
        for value in ["arm64", "x86_64", "arm64 x86_64 i386", ""]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.release.validate_architectures(value, "universal")

    def test_disk_image_accepts_only_the_fixed_applications_shortcut(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "payload").write_bytes(b"signed app fixture")
            self.release.write_inventory(root)
            (root / "Applications").symlink_to("/Applications")
            self.release.verify_inventory(root, disk_image=True)
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root)
            (root / "Applications").unlink()
            (root / "Applications").symlink_to("/tmp")
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root, disk_image=True)
            (root / "Applications").unlink()
            (root / "Applications").symlink_to("/Applications")
            (root / "other").symlink_to("/Applications")
            with self.assertRaises(ValueError):
                self.release.verify_inventory(root, disk_image=True)

    def test_known_v8_exception_requires_complete_report_and_exact_failure(self):
        report = "\n".join([
            *["✘ Test newDrawingsAreDistinctOpaqueContainedAndRegistered() recorded an issue at M15CharacterPackTests.swift:190:13: Expectation failed" for _ in range(48)],
            "✘ Test newDrawingsAreDistinctOpaqueContainedAndRegistered() failed after 75 seconds with 48 issues.",
            '✘ Suite "M15 authored animation quality" failed after 80 seconds with 48 issues.',
            "✘ Test run with 128 tests in 13 suites failed after 93 seconds with 48 issues.",
            "✔ Test run with 50 tests in 10 suites passed after 4 seconds.",
            "✔ Test run with 51 tests in 9 suites passed after 1 seconds.",
            "✔ Test run with 344 tests in 33 suites passed after 9 seconds.",
        ])
        self.assertTrue(self.release.only_known_v8_failure(report))
        for changed in [report.replace("with 48 issues", "with 49 issues"),
                        report.replace("with 344 tests", "with 343 tests"),
                        report + "\n✘ Test differentFailure() failed after 1 seconds with 1 issue.",
                        report + "\nerror: compiler failed", report[:100], ""]:
            with self.subTest(report=changed[-100:]):
                self.assertFalse(self.release.only_known_v8_failure(changed))

    def test_release_exception_is_off_without_approval_and_scoped_to_one_version(self):
        policy = {"version": "1.0.0", "approved": True, "test": "newDrawingsAreDistinctOpaqueContainedAndRegistered", "issues": 48}
        self.release.validate_v8_approval(policy, "1.0.0")
        for value, version in [({}, "1.0.0"), ({**policy, "approved": False}, "1.0.0"),
                               (policy, "1.0.1"), ({**policy, "issues": 49}, "1.0.0")]:
            with self.assertRaises(ValueError):
                self.release.validate_v8_approval(value, version)

    def test_known_v8_report_accepts_complete_swift62_aggregate_without_other_failures(self):
        report = "\n".join([
            *["✘ Test newDrawingsAreDistinctOpaqueContainedAndRegistered() recorded an issue at M15CharacterPackTests.swift:190:13: Expectation failed" for _ in range(48)],
            "✘ Test newDrawingsAreDistinctOpaqueContainedAndRegistered() failed after 170 seconds with 48 issues.",
            '✘ Suite "M15 authored animation quality" failed after 180 seconds with 48 issues.',
            "✘ Test run with 573 tests in 65 suites failed after 200 seconds with 48 issues.",
        ])
        self.assertTrue(self.release.only_known_v8_failure(report))
        for changed in [report.replace("573 tests", "572 tests"), report.replace("65 suites", "64 suites"),
                        report + "\n✘ Test other() failed after 1 seconds with 1 issue."]:
            self.assertFalse(self.release.only_known_v8_failure(changed))

    def test_invalid_cli_inputs_fail_before_creating_output(self):
        for args in [["v1.0.0", "2"], ["1.0.0", "0"], ["1.0.0", "1"]]:
            result = subprocess.run([sys.executable, "-B", str(SCRIPT), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn("release: error:", result.stderr)

    def test_failed_gate_never_reaches_archive_in_strict_mode(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "Config").mkdir()
            (root / "Config/Base.xcconfig").write_text(
                f"CURRENT_PROJECT_VERSION = 1\nPETSCAPE_BUNDLE_ID = {self.release.BUNDLE_ID}\n")
            (root / "CHANGELOG.md").write_text("## [Unreleased]\n- Candidate\n")
            phases = []

            def failed_phase(name, command, logs, results):
                phases.append(name)
                results[name] = 1
                return 1

            def fake_output(command):
                return "Xcode 26.2" if command == ["xcodebuild", "-version"] else ""

            with patch.object(self.release, "ROOT", root), patch.object(sys, "argv", ["release", "1.0.0", "2"]), \
                    patch.object(self.release, "output", side_effect=fake_output), \
                    patch.object(self.release.shutil, "which", return_value="/usr/bin/tool"), \
                    patch.object(self.release, "run_phase", side_effect=failed_phase):
                with self.assertRaisesRegex(ValueError, "quality gates failed"):
                    self.release.main()
            self.assertNotIn("archive", phases)
            self.assertFalse(list(root.rglob("*.zip")))

    def test_wrong_bundle_version_or_signature_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / "PetScape.app"
            (app / "Contents/MacOS").mkdir(parents=True)
            executable = app / "Contents/MacOS/PetScape"
            executable.write_bytes(b"fixture")
            executable.chmod(0o755)
            info = {"CFBundleIdentifier": self.release.BUNDLE_ID, "CFBundleShortVersionString": "0.1.0",
                    "CFBundleVersion": "2", "CFBundleExecutable": "PetScape", "LSMinimumSystemVersion": "14.0",
                    "LSUIElement": True, "NSAudioCaptureUsageDescription": "Optional audio"}
            plist = app / "Contents/Info.plist"
            plist.write_bytes(plistlib.dumps(info))
            with self.assertRaisesRegex(ValueError, "CFBundleShortVersionString"):
                self.release.validate_bundle(app, "1.0.0", "2")
            info["CFBundleShortVersionString"] = "1.0.0"
            plist.write_bytes(plistlib.dumps(info))
            for language in ["en", "pt-BR"]:
                directory = app / f"Contents/Resources/{language}.lproj"
                directory.mkdir(parents=True)
                for name in ["Localizable.strings", "InfoPlist.strings"]:
                    if language == "en" and name == "Localizable.strings":
                        continue  # English uses source-key fallback; Xcode need not emit this file.
                    (directory / name).write_text("fixture")

            def fake_codesign(command):
                if command[0] == "lipo":
                    return "arm64"
                if "--verify" in command:
                    return ""
                return "Signature=Developer ID\nAuthority=Example\nTeamIdentifier=EXAMPLE"

            with patch.object(self.release, "output", side_effect=fake_codesign):
                with self.assertRaisesRegex(ValueError, "expected ad-hoc signature"):
                    self.release.validate_bundle(app, "1.0.0", "2")


if __name__ == "__main__":
    unittest.main()
