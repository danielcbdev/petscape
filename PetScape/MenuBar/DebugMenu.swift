#if DEBUG
    import SwiftUI

    /// Developer controls, localized like the rest of the menu in DEBUG builds.
    struct DebugMenu: View {
        @Bindable var model: DebugOverlayModel

        var body: some View {
            Menu {
                Button {
                    model.jump()
                } label: {
                    Text("Jump vertically")
                }
                Button {
                    model.jump(horizontalOffset: -60)
                } label: {
                    Text("Short jump left")
                }
                Button {
                    model.jump(horizontalOffset: 60)
                } label: {
                    Text("Short jump right")
                }
                Button {
                    model.jumpToDock()
                } label: {
                    Text("Jump to Dock")
                }
                Button {
                    model.setIdle(true)
                } label: {
                    Text("Idle")
                }
                Button {
                    model.setIdle(false)
                } label: {
                    Text("Walk")
                }
                Divider()
                Toggle(isOn: $model.showsOverlayBounds) { Text("Show overlay bounds") }
                Toggle(isOn: $model.showsPassthroughState) { Text("Show pass-through state") }
                Toggle(isOn: $model.showsWalkway) { Text("Show walkway") }
                Toggle(isOn: $model.showsWindowSurfaces) { Text("Show window surfaces") }
                if model.showsWindowSurfaces {
                    windowSurfaceStatus
                }
                // A menu cannot host a live Stepper, so the stepper is a submenu of fixed steps (T6.3).
                Menu {
                    Button {
                        model.adjustDockOffset(by: 1)
                    } label: {
                        Text("Raise 1 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: -1)
                    } label: {
                        Text("Lower 1 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: 5)
                    } label: {
                        Text("Raise 5 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: -5)
                    } label: {
                        Text("Lower 5 pt")
                    }
                    Divider()
                    Button {
                        model.setDockOffset(0)
                    } label: {
                        Text("Reset to 0 pt")
                    }
                } label: {
                    Text("Dock offset: \(model.dockOffset, format: .number.sign(strategy: .always())) pt")
                }
            } label: {
                Text("Debug")
            }
        }

        @ViewBuilder private var windowSurfaceStatus: some View {
            switch model.windowSurfaceStatus {
            case .interactionDisabled: Text("Enable Interact with windows in Settings.")
            case .permissionMissing: Text("Accessibility permission is missing.")
            case .noSegments: Text("Tracking is enabled; no visible window top segments were detected.")
            case .segmentCount(let count): Text("Visible window segments detected: \(count).")
            }
        }
    }
#endif
