#if DEBUG
    import SwiftUI

    /// "Debug" submenu (DEBUG builds only; strings are not localized on purpose).
    struct DebugMenu: View {
        @Bindable var model: DebugOverlayModel

        var body: some View {
            Menu {
                Button {
                    model.jump()
                } label: {
                    Text(verbatim: "Jump vertically")
                }
                Button {
                    model.jump(horizontalOffset: -60)
                } label: {
                    Text(verbatim: "Short jump left")
                }
                Button {
                    model.jump(horizontalOffset: 60)
                } label: {
                    Text(verbatim: "Short jump right")
                }
                Button {
                    model.jumpToDock()
                } label: {
                    Text(verbatim: "Jump to Dock")
                }
                Button {
                    model.setIdle(true)
                } label: {
                    Text(verbatim: "Idle")
                }
                Button {
                    model.setIdle(false)
                } label: {
                    Text(verbatim: "Walk")
                }
                Divider()
                Toggle(isOn: $model.showsOverlayBounds) { Text(verbatim: "Show overlay bounds") }
                Toggle(isOn: $model.showsPassthroughState) { Text(verbatim: "Show pass-through state") }
                Toggle(isOn: $model.showsWalkway) { Text(verbatim: "Show walkway") }
                // A menu cannot host a live Stepper, so the stepper is a submenu of fixed steps (T6.3).
                Menu {
                    Button {
                        model.adjustDockOffset(by: 1)
                    } label: {
                        Text(verbatim: "Raise 1 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: -1)
                    } label: {
                        Text(verbatim: "Lower 1 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: 5)
                    } label: {
                        Text(verbatim: "Raise 5 pt")
                    }
                    Button {
                        model.adjustDockOffset(by: -5)
                    } label: {
                        Text(verbatim: "Lower 5 pt")
                    }
                    Divider()
                    Button {
                        model.setDockOffset(0)
                    } label: {
                        Text(verbatim: "Reset to 0 pt")
                    }
                } label: {
                    Text(verbatim: "Dock offset: \(model.dockOffset.formatted(.number.sign(strategy: .always()))) pt")
                }
            } label: {
                Text(verbatim: "Debug")
            }
        }
    }
#endif
