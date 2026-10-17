#if DEBUG
    import SwiftUI

    /// "Debug" submenu (DEBUG builds only; strings are not localized on purpose).
    struct DebugMenu: View {
        @Bindable var model: DebugOverlayModel

        var body: some View {
            Menu {
                Toggle(isOn: $model.showsOverlayBounds) { Text(verbatim: "Show overlay bounds") }
                Toggle(isOn: $model.showsPassthroughState) { Text(verbatim: "Show pass-through state") }
            } label: {
                Text(verbatim: "Debug")
            }
        }
    }
#endif
