# Modules

Decision record: [ADR-0002](../decisions/0002-project-structure.md).

## Repository layout (target state after M2)

```text
petscape/
├── AGENTS.md / CLAUDE.md / CODEX.md      # agent instructions (AGENTS.md is canonical)
├── README.md
├── Makefile                               # canonical build/test/lint entry points (M2)
├── .swift-format                          # formatter/linter config (M2)
├── Config/                                # xcconfig files: Base, Debug, Release, bundle ID (M2)
├── PetScape.xcodeproj                     # app target + UI tests only (M2)
├── PetScape/                              # app target sources (SwiftUI shell)
│   ├── App/                               # PetScapeApp, AppDelegate, AppContainer
│   ├── MenuBar/
│   ├── Settings/                          # (M9)
│   └── Resources/                         # Info.plist, Assets.xcassets, Localizable.xcstrings
├── PetScapeUITests/
├── Packages/PetScapeKit/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── PetScapeCore/
│   │   ├── PetScapePlatform/
│   │   ├── PetScapeRendering/
│   │   └── PetScapeRuntime/
│   └── Tests/
│       ├── PetScapeCoreTests/
│       ├── PetScapePlatformTests/
│       ├── PetScapeRenderingTests/
│       └── PetScapeRuntimeTests/
├── assets/                                # source art (originals are read-only) + character packs
├── docs/
└── scripts/                               # small shell helpers (only when needed)
```

## Dependency graph

```mermaid
flowchart BT
  Core[PetScapeCore]
  Platform[PetScapePlatform] --> Core
  Rendering[PetScapeRendering] --> Core
  Runtime[PetScapeRuntime] --> Core
  Runtime --> Platform
  Runtime --> Rendering
  App[PetScape app target] --> Runtime
  App --> Platform
  App --> Core
```

No cycles. `Platform` and `Rendering` never depend on each other; they meet only in `Runtime`.

## Module responsibilities

### PetScapeCore — the domain (pure Swift)

Imports: Foundation, CoreGraphics (geometry value types only: the macOS 27 SDK's Foundation no longer
re-exports its Swift overlay), `os`. No UI frameworks. Most types are `Sendable` value types. Default actor
isolation: **nonisolated**.

| Folder | Contents |
|---|---|
| `Geometry/` | `Segment`, `ScreenID`, `ScreenDescriptor`, `QuartzPoint`/`QuartzRect`, `CoordinateConverter` (AppKit global ↔ Quartz global ↔ overlay-local, mask cells; see [coordinate-system.md](../specifications/coordinate-system.md)) on CoreGraphics' `CGPoint`/`CGRect`/`CGVector` |
| `RunState/` | `UserIntent`, `SuspensionReason`, `RunState`/`RunStatus` (pure policy: intent × system conditions → visibility, frames, idle cursor monitor), `FullScreenSpaceRule` (Dock-window decision, T3.10) |
| `Time/` | `FixedStepAccumulator` (M5); `SimulationTime`, `Clock` + `ManualClock` when a consumer needs them (world time is a `Double` so far) |
| `Random/` | `RandomSource` protocol, `SeededRandomSource` (SplitMix64) |
| `Characters/` | `CharacterManifest` (Codable, schema v1), `ManifestValidator`, `CharacterDefinition` (validated, resolved model) |
| `Animation/` | `AnimationClip`, `AnimationPlayer` (time → frame index, events), `AnimationRequest`, fallback resolution |
| `Pets/` | `PetID`, `Pet` (state container), `SurfaceAttachment`, `Facing`; `Personality`, `Needs` (M9) |
| `Surfaces/` | `Surface` (horizontal so far), `SurfaceID`, `SurfaceKind`, `SurfaceMap` (queries, diffs), `DockGeometryEstimator` (pure heuristic, M6) |
| `Physics/` | `KinematicBody`, `PhysicsStepper`, `JumpSolver` (M8) |
| `Behavior/` | `PetState` (MVP machine: spawning/walking/turning/recovering), `BehaviorTuning`; HSM, `PetEvent`, `TransitionTable`, `ActivitySelector` (M7–M9) |
| `World/` | `PetWorld` (owns pets + surface map, `step(dt:into:)`), `WorldInput` (screens, surfaces; cursor in M10), `WorldEvent`, `RenderSnapshot` + `PetRenderState` |
| `Diagnostics/` | `Log` categories (thin wrappers over `os.Logger`) |

### PetScapePlatform — macOS environment adapters

Imports: Core, AppKit, CoreGraphics, ApplicationServices, ServiceManagement. Default isolation:
**MainActor**. Adapters are thin: they read the system and convert to Core values; heuristics
live in Core so they can be tested.

| Folder | Contents |
|---|---|
| `Screens/` | `ScreenProvider` (NSScreen → `ScreenDescriptor`, change notifications) |
| `Dock/` | `DockGeometryProvider` (feeds `DockGeometryEstimator` with screen data + optional Dock prefs hints) |
| `Input/` | `CursorSampler` (`NSEvent.mouseLocation`, global mouse-moved monitor) |
| `SystemEvents/` | `SystemEventsMonitor` (sleep/wake, screens sleep, session resign/become active, lock), `FullScreenSpaceDetector` (`activeSpaceDidChange` → two `CGWindowList` reads → `FullScreenSpaceRule`) |
| `Preferences/` | `PreferencesStore` protocol + `UserDefaultsPreferencesStore`, `InMemoryPreferencesStore` (tests) |
| `Permissions/` | `AccessibilityPermission` (M12) |
| `WindowTracking/` | `WindowTracker` protocol + implementations (M12) |
| `LoginItem/` | `LoginItemController` via `SMAppService` (M9) |

### PetScapeRendering — Core Animation renderer and overlay windows

Decision: [ADR-0015](../decisions/0015-core-animation-renderer.md). Imports: Core, AppKit, QuartzCore, ImageIO. Default isolation: **MainActor**, except the image
decoding service, which is explicitly `nonisolated`/`@concurrent`.

| Folder | Contents |
|---|---|
| `Overlay/` | `OverlayPanel` (NSPanel subclass), `OverlayContentView` (layer-backed, non-flipped `NSView`; receives mouse events while interactive), `OverlayWindowManager` (one per screen; also reports overlay occlusion, since only it knows the panels) |
| `Layers/` | `PetLayer` (one `CALayer` per pet: frame image, size, anchor, mirroring; implicit animations disabled), `PetRenderer` (snapshot → layers keyed by `PetID`, global → overlay-local), `DebugOverlayLayer` (`CAShapeLayer`s, DEBUG only) |
| `Images/` | `ImageDecoder` (ImageIO, downsampling), `FrameImageStore` (decoded `CGImage` cache), `HitMask` (alpha mask) |
| `HitTesting/` | `PetHitTester` (global point → pet ID using masks) |

### PetScapeRuntime — orchestration

Imports: Core, Platform, Rendering, AppKit. Default isolation: **MainActor**.

| Type | Role |
|---|---|
| `PetRuntime` | Owns `PetWorld`, the `FixedStepAccumulator`, `PetRenderer` and `PetHitTester`; builds the `OverlayCoordinator`; per frame: steps → snapshot → render → hit masks; persists pause/hide through `PreferencesStore`; M5 walkway = bottom of the host screen |
| `FrameDriver` | Protocol for "call me each display frame"; `DisplayLinkFrameDriver` wraps the overlay view's `CADisplayLink` (pause, preferred frame rate) |
| `MousePassthroughController` | Decides `ignoresMouseEvents` per overlay from hit tests (`PetHitTesting`, implemented by Rendering's `PetHitTester`) |
| `RunStateController` | Combines user intent (pause/hide) with system state (sleep, lock, occlusion, full-screen Space, no screens) via Core's `RunStatus.resolve` |
| `OverlayCoordinator` | M3 wiring: screens → overlays, run state → visibility / frame driver / idle cursor monitor, cursor → pass-through; hooks (`onFrame`, `onScreensChange`, `onStatusChange`, `onMouseEvent`, `needsFrames`, `preferredFramesPerSecond`) used by `PetRuntime` |
| `CharacterLoader` | Loads manifest + frame images for a pack, reports errors |

### App target — SwiftUI shell and composition root

`PetScapeApp`, `AppDelegate`, `AppContainer`, `MenuBarContent`, (M9) `SettingsView`. Contains no
domain logic; views talk to a small `@Observable` `AppModel` that forwards intents to `PetRuntime`.

## When to split or merge modules

- Split `PetScapeCore` only when a sub-area needs a different dependency set or compile times
  become a problem (measure first). Candidate: `PetScapeBehavior` once utility AI grows.
- Do not create a module per "engine". Engines are folders inside Core with clear type boundaries.
- Any new module requires an ADR update.
