# macOS Integration

The highest-risk area. Everything marked **[validate]** is an expectation to be confirmed by the
PoC ([proof-of-concept.md](../planning/proof-of-concept.md)), not an established fact.
Decision: [ADR-0003](../decisions/0003-overlay-window-strategy.md).

## App shell

| Topic | Decision |
|---|---|
| Activation policy | `LSUIElement = YES` (accessory app: no Dock icon, no app menu) |
| Menu bar | SwiftUI `MenuBarExtra` (menu style) for the MVP; fall back to `NSStatusItem` only if a needed feature is missing |
| Settings | SwiftUI `Settings` scene (M9), opened via `SettingsLink` / `openSettings` (macOS 14+) |
| AppKit bridge | `@NSApplicationDelegateAdaptor(AppDelegate.self)`; the delegate owns the `AppContainer` |
| Focus | Our overlay windows never become key or main; opening Settings activates the app normally |

M9 Settings forwards intents through a shared observable SettingsModel to PetRuntime. Production
preferences restore size/speed/activity toggles before spawn. The public SMAppService.mainApp adapter
is injected at the composition root. Launch only reads its status; registration/unregistration happens
on explicit Settings actions. Status refreshes on window opening and application activation, without
polling. Login failures remain visible while local preferences continue to work. Tests inject a fake
login service and an isolated preference suite, including for Restore Defaults.

## Overlay window strategies compared

| Criterion | 1. One large overlay per screen | 2. Small window per pet | 3. Hybrid (chosen): large overlay per screen + dynamic pass-through |
|---|---|---|---|
| Click-through | All-or-nothing per window unless toggled | Small blocking rect around the pet (transparent margins still block unless toggled) | Pass-through by default; enabled only when the cursor is over pet pixels |
| Movement cost | Sprite moves inside a static window (cheap, GPU only) | `setFrameOrigin` every frame → WindowServer work per frame **[validate cost]** | Sprite moves inside a static window |
| Multiple pets | One view renders all | N windows and layer trees | One view per screen renders all |
| Multiple monitors | One overlay per screen required (a window cannot reliably span displays when "Displays have separate Spaces" is on) | Natural | One overlay per screen; pets handed off between overlays |
| Interaction (drag) | Needs toggling | Natural | Needs toggling (validated in PoC E2/E4) |
| Complexity | Low | Medium (window churn, z-order) | Medium |

Chosen: **3**. Strategy 2 remains the fallback if PoC E2 shows dynamic toggling is unreliable.

## Overlay window configuration

| Property | Value | Why |
|---|---|---|
| Class | `NSPanel` subclass `OverlayPanel` | Panels can be non-activating |
| Style mask | `[.borderless, .nonactivatingPanel]` | No chrome; clicking a pet does not activate the app |
| `canBecomeKey` / `canBecomeMain` | `false` (override) | Never steal keyboard focus |
| `isOpaque` / `backgroundColor` / `hasShadow` | `false` / `.clear` / `false` | Per-pixel transparency |
| Level | `CGWindowLevelForKey(.dockWindow) - 1` (19) | Just **below** the Dock: above normal/floating/modal windows, but a revealed auto-hide Dock (which posts no notification) slides over the pet instead of being covered by it; magnified icons draw over the pet. Validated in PoC Dock test 5b. Below the menu bar (24), pop-up menus (101), screen saver |
| Collection behavior | `[.canJoinAllSpaces, .stationary, .ignoresCycle]` | Visible on every Space, static in Mission Control, not in Cmd-` cycling. **No** `.fullScreenAuxiliary`. PoC: this does **not** keep the panel out of full-screen app Spaces on macOS 27 — see the full-screen rule below |
| Frame | `screen.frame` (full screen, including menu bar and Dock areas) | The pet must overlap the Dock region |
| `ignoresMouseEvents` | `true` by default; toggled by `MousePassthroughController` | Click-through |
| `isReleasedWhenClosed` | `false` | Lifetime managed by `OverlayWindowManager` |
| Accessibility | Overlay and sprites are hidden from the accessibility tree | Pets are decorative (NFR-10) |
| Content | `OverlayContentView`: layer-backed, non-flipped `NSView` with a clear layer; one `PetLayer` (`CALayer`) per pet ([ADR-0015](../decisions/0015-core-animation-renderer.md)) | Overlay-local coordinates = window-local points (origin = screen origin) |

## Click-through strategies

Visual transparency does **not** imply event transparency. Three strategies are tested in PoC E2:

| ID | Strategy | Expected behavior | Notes |
|---|---|---|---|
| A | `ignoresMouseEvents = true` permanently | All clicks pass through; pet not interactive | Baseline; always works |
| B | `ignoresMouseEvents = false`, rely on WindowServer alpha hit-testing of transparent pixels | Historically, clicks on fully transparent pixels of non-opaque windows pass through, but behavior with layer/Metal-backed content is not guaranteed **[validate]** | Not relied on |
| C | **Dynamic**: `true` by default; `MousePassthroughController` sets `false` only while the cursor is over a pet's alpha mask, and keeps it `false` during a drag | Deterministic; ≤ 1 frame latency; no permission | **Chosen** |

Strategy C cursor source:

- While the simulation runs: `NSEvent.mouseLocation` sampled each frame (cheap; no permission).
- While paused (no frames): `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` wakes the
  controller. Apple documents permission requirements for *key* events in global monitors; mouse
  events are expected to work without Accessibility **[validate]**. If not, fall back to a low-rate
  (10 Hz) timer only while paused and visible, and document the cost.
- A tracking area (`.mouseMoved`, `.activeAlways`) on `OverlayContentView` handles moves while our window
  accepts the mouse.
- The overlay never becomes interactive while a mouse button is already held (a drag from another app,
  e.g. a file dragged to the Dock, passes over the pet untouched), and a drag that lost its mouse-up is
  ended as soon as a sample shows no button held.
- M3 finding (2026-10-17, macOS 27.0.1): the content view's tracking area (`.mouseMoved`, `.activeAlways`)
  also receives mouse-moved events **while the overlay ignores the mouse**, delivered in step with the
  display refresh; most pass-through toggles came from them (input event → toggle 9–14 ms, ≤ 1 frame;
  frame-sampled toggles ~0.4 ms). Consequence: the app wakes on mouse movement anywhere on the overlay's
  screen, also while paused (no movement = no wakeups). The global monitor is kept as specified, because
  this delivery is undocumented.

## Spaces, Mission Control, Stage Manager, fullscreen

| Situation | Expected | Status |
|---|---|---|
| Switching Spaces | Overlay stays (canJoinAllSpaces); pet keeps walking | [validate] |
| Mission Control / App Exposé | Overlay stays in place (`.stationary`), not shown as a thumbnail | [validate] |
| Stage Manager | Overlay above stage strip; clicks pass through | [validate] |
| Fullscreen app Space | Overlay hidden by the **full-screen rule**: on `activeSpaceDidChange`, if `CGWindowList` shows no on-screen window owned by the Dock at the Dock level (read twice, 400 ms apart, after the transition) the Space is treated as full screen → run state `suspended`, overlay ordered out; shown again when the Dock window is back | Validated in PoC (S5): hidden ~1 s after entering a full-screen Space, shown on return; Dock auto-hide does not trigger it (Dock window stays on screen). Product decision: never cover full-screen apps in the MVP |
| Screen locked / screen saver | Run state `suspended`; overlay ordered out | Planned |
| Display sleep (`screensDidSleep`) | `suspended` | Planned |
| Fast user switching (`sessionDidResignActive`) | `suspended` | Planned |

## Multiple monitors, Retina, scaling

- One overlay per `NSScreen`; recreated/re-laid out on `didChangeScreenParametersNotification`.
- MVP renders only on the screen that hosts the Dock (other overlays not created); M14 enables all.
- Screen identity: `NSScreen.deviceDescription["NSScreenNumber"]` (`CGDirectDisplayID`) — stable for
  a session, not across reboots; never persist it as the only key.
- Retina: layers are laid out in points and composited at the screen's `backingScaleFactor`; frame
  images are decoded for the maximum backing scale among screens (re-decoding on change is not
  needed if we decode at 2x).
- Mixed DPI across monitors: a pet crossing screens keeps its point size; image density may be
  higher than needed on a 1x screen (acceptable).
- Coordinate conversions: [coordinate-system.md](../specifications/coordinate-system.md).

## Dock

Summary (details: [surface-detection.md](../specifications/surface-detection.md),
[ADR-0009](../decisions/0009-dock-geometry.md)): estimate the Dock edge from the difference between
`NSScreen.frame` and `NSScreen.visibleFrame`; Dock position is the edge with the inset (bottom, left
or right); autohide yields a near-zero inset. No private APIs. A manual vertical offset adjusts
visual alignment. The Dock's horizontal extent is unknown without Accessibility; the MVP walks the
full screen width.

## Energy and system events

| Notification | Action |
|---|---|
| `NSWorkspace.willSleepNotification` / `didWakeNotification` | suspend / resume (reset accumulator) |
| `NSWorkspace.screensDidSleepNotification` / `screensDidWakeNotification` | suspend / resume |
| `NSWorkspace.sessionDidResignActiveNotification` / `sessionDidBecomeActiveNotification` | suspend / resume |
| `com.apple.screenIsLocked` / `screenIsUnlocked` (distributed notifications) | suspend / resume **[validate availability]** |
| `NSWindow.didChangeOcclusionStateNotification` | suspend when overlay not visible |
| `NSApplication.didChangeScreenParametersNotification` | rebuild screens, overlays, Dock surface |

## Non-interference rules (hard requirements)

- Never call APIs that move, resize, close, focus or otherwise manipulate other apps' windows.
- Never become key/main; never activate the app from overlay clicks.
- Never raise level above the menu bar; never use `.screenSaver` or higher.
- Never cover fullscreen apps in the MVP.
- No private APIs, no code injection, no scripting additions, no Accessibility in the MVP.

## Known limitations and risks

| Risk | Impact | Mitigation |
|---|---|---|
| Dynamic pass-through flicker/latency | Missed or stolen clicks near the pet | Hit mask with small inset; ≤ 1 frame latency; PoC measures |
| A future pet pose that dips into the Dock shelf is hidden by the Dock (overlay is below it) | Cosmetic | Keep contact points on or above the shelf edge (anchor at the paws) |
| Window level behavior changes between macOS versions | Overlay hidden or too high | PoC on current macOS; manual test matrix per release |
| Global mouse monitor may require permission on some macOS versions | Pet not draggable while paused | Low-rate fallback timer only while paused |
| Occlusion notification unreliable for full-screen transparent windows | Missed energy savings | Combine with screens/space notifications; measure |
| `visibleFrame` does not reflect the floating Dock's real shape | Pet floats a few points above/below the Dock shelf | Manual offset; AX-based Dock frame (optional, M12+) |

## Proposed M10 extension (not adopted)

[Interaction architecture](interaction-system.md) records the inspected input implementation,
API comparison and routing limitations. [ADR-0020](../decisions/0020-selective-input-and-focus.md)
proposes comparing the current full-screen gate to a small input panel while rendering remains
static/click-through. ADR-0003 still governs production; no second panel is approved by planning.
Native focus, transparent-hole/Dock input and drag continuity must pass the
[M10.0 PoC](../planning/m10-native-poc.md) before owner-approved adoption. Returning nil from
NSView.hitTest does not resend WindowServer-selected input to another application.
