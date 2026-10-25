# Canonical entry points for humans, CI and agents (ADR-0011). See docs/development/setup.md.
# Builds from `make` treat warnings as errors in every configuration (zero-warning policy).

PROJECT      := PetScape.xcodeproj
SCHEME       := PetScape
PACKAGE      := Packages/PetScapeKit
DERIVED_DATA := build/DerivedData
APP          := $(DERIVED_DATA)/Build/Products/Debug/PetScape.app

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' \
	-derivedDataPath $(DERIVED_DATA) SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO GCC_TREAT_WARNINGS_AS_ERRORS=YES

# Matches `import M`, `@preconcurrency import M`, `public import M`, `import struct M.T`.
IMPORT_OF := ^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?

SWIFT_FORMAT_PATHS := PetScape PetScapeUITests $(PACKAGE)/Package.swift $(PACKAGE)/Sources $(PACKAGE)/Tests

.PHONY: build build-release test test-core lint format run

build:
	$(XCODEBUILD) -configuration Debug build
	@/usr/libexec/PlistBuddy -c 'Print :NSAudioCaptureUsageDescription' "$(APP)/Contents/Info.plist" > /dev/null

# Universal optimized build, also used as the release workflow's early toolchain gate.
build-release:
	$(XCODEBUILD) -configuration Release build ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
	@/usr/libexec/PlistBuddy -c 'Print :NSAudioCaptureUsageDescription' "$(DERIVED_DATA)/Build/Products/Release/PetScape.app/Contents/Info.plist" > /dev/null

test: test-core
	$(XCODEBUILD) -configuration Debug test

test-core:
	swift test --package-path $(PACKAGE) -Xswiftc -warnings-as-errors

# Style (swift format) plus the module boundary rules from AGENTS.md §3 (AC-M2-03).
lint:
	swift format lint --strict --recursive --parallel $(SWIFT_FORMAT_PATHS)
	@! grep -rnE '$(IMPORT_OF)(AppKit|SwiftUI|QuartzCore|SpriteKit|ApplicationServices|PetScape[A-Za-z]+)\b' \
		$(PACKAGE)/Sources/PetScapeCore || { echo "error: PetScapeCore may import only Foundation, CoreGraphics and os"; exit 1; }
	@! grep -rnE '$(IMPORT_OF)(SpriteKit|PetScapePlatform)\b' \
		$(PACKAGE)/Sources/PetScapeRendering || { echo "error: PetScapeRendering must not import SpriteKit or PetScapePlatform"; exit 1; }
	@! grep -rnE '$(IMPORT_OF)(SpriteKit|PetScapeRendering)\b' \
		$(PACKAGE)/Sources/PetScapePlatform || { echo "error: PetScapePlatform must not import SpriteKit or PetScapeRendering"; exit 1; }

format:
	swift format --in-place --recursive --parallel $(SWIFT_FORMAT_PATHS)

run: build
	open $(APP)
