"""Ad-hoc Release rehearsal/packaging using only system tools and Python's standard library."""

import argparse
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "io.github.danielcbdev.petscape"
INVENTORY = "CONTENTS.sha256"
KNOWN_V8_TEST = "newDrawingsAreDistinctOpaqueContainedAndRegistered"


def validate_inputs(version, build):
    if not re.fullmatch(r"(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})", version):
        raise ValueError("version must be stable MAJOR.MINOR.PATCH (no v prefix or leading zeroes)")
    if not re.fullmatch(r"[1-9][0-9]{0,8}", build):
        raise ValueError("build must be a positive integer of at most nine digits, without leading zeroes")


def release_notes(changelog, version):
    entries = dict(re.findall(r"^## \[([^\]]+)\][^\n]*\n([\s\S]*?)(?=^## |\Z)", changelog, flags=re.MULTILINE))
    notes = entries.get(version, entries.get("Unreleased", "")).strip()
    if not notes or not re.search(r"^- \S", notes, flags=re.MULTILINE):
        raise ValueError("CHANGELOG.md needs a nonempty matching version or Unreleased section")
    return notes


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest() if hasattr(hashlib, "file_digest") else _digest(stream)


def _digest(stream):
    result = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        result.update(chunk)
    return result.hexdigest()


def inventory(root, disk_image=False):
    result = {}
    if disk_image and (not (root / "Applications").is_symlink() or (root / "Applications").readlink() != Path("/Applications")):
        raise ValueError("disk image needs the fixed /Applications shortcut")
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if disk_image and relative.parts[0] in {".fseventsd", ".Trashes", ".DS_Store", ".HFS+ Private Directory Data\r"}:
            continue  # Filesystem metadata, outside the signed application and release payload.
        if path.is_symlink():
            if disk_image and relative.as_posix() == "Applications" and path.readlink() == Path("/Applications"):
                continue
            raise ValueError(f"unexpected symlink in package: {path}")
        if path.is_file() and path.relative_to(root).as_posix() != INVENTORY:
            name = path.relative_to(root).as_posix()
            if "\n" in name or "\r" in name or "\\" in name:
                raise ValueError("unsupported checksum filename")
            result[name] = digest(path)
    return result


def write_inventory(root):
    (root / INVENTORY).write_text("".join(f"{value}  {name}\n" for name, value in inventory(root).items()))


def verify_inventory(root, disk_image=False):
    expected = {}
    for line in (root / INVENTORY).read_text().splitlines():
        value, name = line.split("  ", 1)
        if not re.fullmatch(r"[a-f0-9]{64}", value) or name in expected:
            raise ValueError("invalid checksum inventory")
        expected[name] = value
    if not expected or inventory(root, disk_image=disk_image) != expected:
        raise ValueError("bundle checksum mismatch (missing, changed or extra file)")


def image_paths(value):
    if isinstance(value, dict):
        paths = {value["image"]} if isinstance(value.get("image"), str) else set()
        for child in value.values():
            paths.update(image_paths(child))
        return paths
    if isinstance(value, list):
        return set().union(*(image_paths(child) for child in value))
    return set()


def verify_characters(source, target):
    manifests = sorted(source.glob("*/character.json"))
    if not manifests:
        raise ValueError("no bundled character manifests")
    expected = set()
    ids = set()
    for manifest in manifests:
        data = json.loads(manifest.read_bytes())
        character_id = data.get("id")
        if character_id in ids:
            raise ValueError("duplicate bundled character ID")
        ids.add(character_id)
        paths = image_paths(data)
        if not paths:
            raise ValueError("character has no referenced images")
        for name in paths | {"character.json"}:
            parts = PurePosixPath(name)
            if parts.is_absolute() or any(part in (".", "..") for part in name.split("/")) or "\\" in name:
                raise ValueError("unsafe character resource path")
            relative = Path(manifest.parent.name) / name
            original, copied = source / relative, target / relative
            if not original.is_file() or not copied.is_file() or digest(original) != digest(copied):
                raise ValueError(f"missing or altered character resource: {relative}")
            expected.add(relative.as_posix())
    if set(inventory(target)) != expected:
        raise ValueError("unexpected character pack contents")


def output(command):
    return subprocess.check_output(command, cwd=ROOT, text=True, stderr=subprocess.STDOUT).strip()


def validate_architectures(actual, architecture):
    expected = {"arm64", "x86_64"} if architecture == "universal" else {"arm64"}
    if set(actual.split()) != expected:
        raise ValueError(f"release architecture mismatch: expected {sorted(expected)}, got {actual}")
    return sorted(expected)


def validate_bundle(app, version, build, architecture="arm64"):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    expected = {"CFBundleIdentifier": BUNDLE_ID, "CFBundleShortVersionString": version,
                "CFBundleVersion": build, "CFBundleExecutable": "PetScape", "LSMinimumSystemVersion": "14.0"}
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"bundle {key}: expected {value}, got {info.get(key)}")
    if not info.get("LSUIElement") or not info.get("NSAudioCaptureUsageDescription"):
        raise ValueError("missing menu-bar flag or system-audio consent copy")
    executable = app / "Contents/MacOS/PetScape"
    if not executable.is_file() or not executable.stat().st_mode & 0o111:
        raise ValueError("missing executable")
    architectures = validate_architectures(output(["lipo", "-archs", str(executable)]), architecture)
    for language in ["en", "pt-BR"]:
        # English UI strings use source-key fallback; Xcode emits the translated catalog only.
        filenames = ["InfoPlist.strings"] + (["Localizable.strings"] if language == "pt-BR" else [])
        for filename in filenames:
            if not (app / f"Contents/Resources/{language}.lproj/{filename}").is_file():
                raise ValueError(f"missing {language} {filename}")
    output(["codesign", "--verify", "--all-architectures", "--deep", "--strict", "--verbose=2", str(app)])
    signatures = []
    for arch in architectures:
        signature = output(["codesign", "-d", "--arch", arch, "--verbose=4", str(app)])
        if "Signature=adhoc" not in signature or "TeamIdentifier=not set" not in signature or "Authority=" in signature:
            raise ValueError("expected ad-hoc signature with no developer authority/team")
        entitlements = output(["codesign", "-d", "--arch", arch, "--entitlements", "-", str(app)])
        plist = re.search(r"<\?xml[\s\S]*</plist>", entitlements)
        if plist and plistlib.loads(plist[0].encode()):
            raise ValueError("unexpected release entitlement (including debug get-task-allow)")
        signatures.append(f"Architecture: {arch}\n{signature}")
    verify_characters(ROOT / "assets/characters", app / "Contents/Resources/characters")
    return "\n\n".join(signatures)


@contextmanager
def mounted_disk_image(path):
    with tempfile.TemporaryDirectory(prefix="petscape-dmg-mount-") as temporary:
        mount = Path(temporary) / "volume"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(path)], check=True)
        try:
            yield mount
        finally:
            subprocess.run(["diskutil", "eject", str(mount)], check=True)


def create_disk_image(payload, path, version, build, architecture):
    with tempfile.TemporaryDirectory(prefix="petscape-dmg-stage-") as temporary:
        stage = Path(temporary) / "PetScape"
        subprocess.run(["ditto", str(payload), str(stage)], check=True)
        (stage / "Applications").symlink_to("/Applications")
        verify_inventory(stage, disk_image=True)
        subprocess.run(["hdiutil", "create", "-volname", f"PetScape {version}", "-srcfolder", str(stage),
                        "-fs", "HFS+", "-format", "UDZO", str(path)], check=True)
    subprocess.run(["hdiutil", "verify", str(path)], check=True)
    with mounted_disk_image(path) as mount:
        verify_inventory(mount, disk_image=True)
        validate_bundle(mount / "PetScape.app", version, build, architecture)
        subprocess.run(["shasum", "-a", "256", "-c", INVENTORY], cwd=mount, check=True, stdout=subprocess.DEVNULL)


def gate_failures(results):
    return [name for name, code in results.items() if code != 0]


def validate_v8_approval(policy, version):
    if not (policy.get("approved") is True and policy.get("version") == version == "1.0.0"
            and policy.get("test") == KNOWN_V8_TEST and policy.get("issues") == 48):
        raise ValueError("no owner-approved V8 exception for this version")


def only_known_v8_failure(report):
    # Fail closed if Swift Testing's output changes or a run is incomplete. Never skip the test.
    summaries = re.findall(r"[✔✘] Test run with (\d+) tests in (\d+) suites (passed|failed)[^\n]*", report)
    split_report = sorted([("128", "13", "failed"), ("50", "10", "passed"),
                           ("51", "9", "passed"), ("344", "33", "passed")])
    aggregate_report = [("573", "65", "failed")]
    if sorted(summaries) not in [split_report, aggregate_report]:
        return False
    failed_summary = re.findall(r"^✘ Test run with [^\n]+", report, re.MULTILINE)
    if len(failed_summary) != 1 or not failed_summary[0].endswith("with 48 issues."):
        return False
    failed_tests = re.findall(r"^✘ Test (?!run with)(\w+)\([^\n]*\) failed[^\n]*", report, re.MULTILINE)
    issues = re.findall(r"^✘ Test (?!run with)(\w+)\([^\n]*\) recorded an issue[^\n]*", report, re.MULTILINE)
    failed_suites = re.findall(r'^✘ Suite "([^"]+)" failed[^\n]*', report, re.MULTILINE)
    return (failed_tests == [KNOWN_V8_TEST] and len(issues) == 48 and set(issues) == {KNOWN_V8_TEST}
            and failed_suites == ["M15 authored animation quality"]
            and not re.search(r"(?:error:|unexpected signal|fatal error|build failed)", report, re.IGNORECASE))


def run_phase(name, command, logs, results):
    print(f"[{name}] {' '.join(map(str, command))}", flush=True)
    with (logs / f"{name}.log").open("w") as stream:
        try:
            code = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=1200).returncode
        except subprocess.TimeoutExpired:
            code = 124
            stream.write("\nPhase timed out after 1200 seconds.\n")
    results[name] = code
    (logs / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"[{name}] exit {code}; log: {logs / (name + '.log')}", flush=True)
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("build")
    parser.add_argument("--architecture", choices=["universal", "arm64"], default="universal")
    parser.add_argument("--allow-known-v8-failure", action="store_true", help="explicit owner-approved 1.0.0 exception only; test stays failed")
    parser.add_argument("--rehearsal", action="store_true", help="diagnostic only; never waives a failed gate or returns success for one")
    args = parser.parse_args()
    validate_inputs(args.version, args.build)
    exception_policy = ROOT / "docs/development/release-exceptions.json"
    if args.allow_known_v8_failure:
        validate_v8_approval(json.loads(exception_policy.read_text()), args.version)
    notes = release_notes((ROOT / "CHANGELOG.md").read_text(), args.version)
    config = (ROOT / "Config/Base.xcconfig").read_text()
    baseline = re.search(r"^CURRENT_PROJECT_VERSION = ([0-9]+)$", config, flags=re.MULTILINE)
    if not baseline or int(args.build) <= int(baseline[1]):
        raise ValueError("build must exceed CURRENT_PROJECT_VERSION in Config/Base.xcconfig")
    if f"PETSCAPE_BUNDLE_ID = {BUNDLE_ID}" not in config:
        raise ValueError("release bundle ID differs from the approved project identity")
    if sys.platform != "darwin":
        raise ValueError("release requires macOS and Xcode 26+ (Swift 6.2+)")
    for tool in ["xcodebuild", "swift", "codesign", "ditto", "hdiutil", "diskutil", "shasum", "lipo", "make", "git"]:
        if not shutil.which(tool):
            raise ValueError(f"missing required tool: {tool}")
    xcode = output(["xcodebuild", "-version"])
    if int(re.search(r"Xcode (\d+)", xcode)[1]) < 26:
        raise ValueError("Xcode 26+ is required")
    dirty = output(["git", "status", "--porcelain"])
    if dirty and not args.rehearsal:
        raise ValueError("release requires a clean checkout; use --rehearsal for diagnostic local edits")
    name = f"PetScape-{args.version}-{args.build}-{args.architecture}"
    arch_setting = "ARCHS=arm64 x86_64" if args.architecture == "universal" else "ARCHS=arm64"
    destination = ROOT / "dist" / ("rehearsal" if args.rehearsal else "release") / name
    if destination.exists():
        raise ValueError(f"output already exists; choose a new build number or move it aside: {destination}")
    destination.mkdir(parents=True)
    logs = destination / "logs"
    logs.mkdir()
    (logs / "environment.txt").write_text(xcode + "\n" + output(["sw_vers"]) + "\n" +
        output(["swift", "--version"]) + "\nHEAD=" + output(["git", "rev-parse", "HEAD"]) +
        f"\nlocal-edits={bool(dirty)}\nrehearsal={args.rehearsal}\n")
    results = {}
    xcb = ["xcodebuild", "-project", "PetScape.xcodeproj", "-scheme", "PetScape",
           "-destination", "platform=macOS", "-derivedDataPath", str(destination / "DerivedData"),
           "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "SWIFT_SUPPRESS_WARNINGS=NO", "GCC_TREAT_WARNINGS_AS_ERRORS=YES"]
    # Run canonical commands intact. A failed make test still blocks publication.
    for phase, command in [("lint", ["make", "lint"]), ("test-core", ["make", "test-core"]),
                           ("test", ["make", "test"]), ("debug", ["make", "build"]),
                           ("release-tests", [sys.executable, "-m", "unittest", "discover", "-s", "scripts/tests", "-v"]),
                           ("release-build", xcb + ["-configuration", "Release", "build", arch_setting, "ONLY_ACTIVE_ARCH=NO"])]:
        run_phase(phase, command, logs, results)
    if (args.rehearsal or args.allow_known_v8_failure) and results["test"]:
        run_phase("ui-separate", xcb + ["-configuration", "Debug", "test"], logs, results)
    with tempfile.TemporaryDirectory(prefix="petscape-assets-") as temporary:
        if run_phase("characters", ["swift", "scripts/copy-referenced-character-assets.swift",
                                   "assets/characters", temporary], logs, results) == 0:
            verify_characters(ROOT / "assets/characters", Path(temporary))
    failures = gate_failures(results)
    approved_failures = []
    if args.allow_known_v8_failure:
        approved_failures = [name for name in ["test-core", "test"] if results[name] == 2
                             and only_known_v8_failure((logs / f"{name}.log").read_text())]
    blocking_failures = [name for name in failures if name not in approved_failures]
    (logs / "gate-review.json").write_text(json.dumps({
        "version": args.version, "build": args.build, "rehearsal": args.rehearsal,
        "failedGates": failures, "ownerApprovedV8Gates": approved_failures,
        "blockingGates": blocking_failures,
    }, indent=2) + "\n")
    if blocking_failures and not args.rehearsal:
        raise ValueError(f"quality gates failed: {', '.join(failures)}; no package produced")
    archive = destination / "PetScape.xcarchive"
    archive_command = xcb + ["-configuration", "Release", "-archivePath", str(archive), "archive",
                             f"MARKETING_VERSION={args.version}", f"CURRENT_PROJECT_VERSION={args.build}",
                             arch_setting, "ONLY_ACTIVE_ARCH=NO", "CODE_SIGN_IDENTITY=-", "DEVELOPMENT_TEAM=",
                             "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO"]
    if run_phase("archive", archive_command, logs, results):
        raise ValueError("Release archive failed; no package produced")
    app = archive / "Products/Applications/PetScape.app"
    (logs / "signature.txt").write_text(validate_bundle(app, args.version, args.build, args.architecture) + "\n")
    payload = destination / name
    payload.mkdir()
    subprocess.run(["ditto", str(app), str(payload / "PetScape.app")], check=True)
    marker = "DIAGNOSTIC REHEARSAL — NOT FOR PUBLICATION" if args.rehearsal else (
        "Owner-approved V8 pixel-QA exception; all other gates passed" if approved_failures else "Quality gates passed")
    (payload / "RELEASE-NOTES.md").write_text(f"# PetScape {args.version} (build {args.build}, {args.architecture})\n\n{marker}\n\n"
        f"Gate failures: {', '.join(failures) or 'none'}.\n\nAd-hoc signed; no developer identity or Apple notarization.\n\n{notes}\n")
    shutil.copyfile(ROOT / "docs/development/install.md", payload / "INSTALL.md")
    shutil.copyfile(ROOT / "LICENSE", payload / "SOURCE-LICENSE.txt")
    shutil.copyfile(ROOT / "ARTWORK-LICENSE.md", payload / "ARTWORK-LICENSE.md")
    if approved_failures:
        shutil.copyfile(exception_policy, payload / "RELEASE-EXCEPTION.json")
    write_inventory(payload)
    verify_inventory(payload)
    archive_zip = destination / f"{name}.zip"
    subprocess.run(["ditto", "-c", "-k", "--keepParent", "--norsrc", str(payload), str(archive_zip)], check=True)
    checksum = destination / "SHA256SUMS"
    archive_dmg = destination / f"{name}.dmg"
    create_disk_image(payload, archive_dmg, args.version, args.build, args.architecture)
    checksum.write_text("".join(f"{digest(path)}  {path.name}\n" for path in [archive_dmg, archive_zip]))
    for path in [archive_dmg, archive_zip]:
        path.with_suffix(path.suffix + ".sha256").write_text(f"{digest(path)}  {path.name}\n")
    subprocess.run(["shasum", "-a", "256", "-c", checksum.name], cwd=destination, check=True)
    with tempfile.TemporaryDirectory(prefix="petscape-roundtrip-") as temporary:
        subprocess.run(["ditto", "-x", "-k", str(archive_zip), temporary], check=True)
        extracted = Path(temporary) / name
        verify_inventory(extracted)
        validate_bundle(extracted / "PetScape.app", args.version, args.build, args.architecture)
        subprocess.run(["shasum", "-a", "256", "-c", INVENTORY], cwd=extracted, check=True, stdout=subprocess.DEVNULL)
    shutil.copyfile(payload / "RELEASE-NOTES.md", destination / "RELEASE-NOTES.md")
    print(f"Verified ZIP and extracted ad-hoc bundle: {archive_zip}\nSHA-256: {digest(archive_zip)}", flush=True)
    print(f"Verified read-only DMG and mounted ad-hoc bundle: {archive_dmg}\nSHA-256: {digest(archive_dmg)}", flush=True)
    if blocking_failures or (args.rehearsal and failures):
        raise ValueError(f"diagnostic package only; gates FAILED: {', '.join(failures)}; publication remains blocked")
    print(marker)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"release: error: {error}", file=sys.stderr)
        sys.exit(1)
