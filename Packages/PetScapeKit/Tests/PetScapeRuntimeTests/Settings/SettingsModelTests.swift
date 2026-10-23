import Foundation
import PetScapeCore
import PetScapePlatform
import Testing

@testable import PetScapeRuntime

@Suite("SettingsModel", .serialized)
struct SettingsModelTests {
    final class LoginService: LaunchAtLoginService {
        var status: LaunchAtLoginStatus = .disabled
        var failure: LaunchAtLoginError?
        var changes: [Bool] = []
        func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
            changes.append(enabled)
            if let failure { throw failure }
            status = enabled ? .enabled : .disabled
        }
    }

    @MainActor
    final class AccessibilityPermissionStub: AccessibilityPermissionProviding {
        private(set) var trustChecks = 0
        private(set) var promptCalls = 0
        private(set) var settingsCalls = 0
        var isTrusted: Bool {
            trustChecks += 1
            return false
        }
        func openSettings() -> Bool { settingsCalls += 1; return true }
        func requestAuthorizationPrompt() { promptCalls += 1 }
    }

    @Test func openingAndRefreshingReadsActualLoginStateWithoutRegistering() {
        let h = PetRuntimeTests.Harness()
        let login = LoginService()
        login.status = .requiresApproval
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: login)
        #expect(model.loginStatus == .requiresApproval)
        #expect(model.isLaunchAtLoginEnabled)
        #expect(login.changes.isEmpty)
        login.status = .notFound
        model.refreshLoginStatus()
        #expect(model.loginStatus == .notFound)
        #expect(!model.isLaunchAtLoginEnabled)
        #expect(login.changes.isEmpty)
    }

    @Test func disabledWindowInteractionDoesNotCheckPermissionOrPrompt() {
        let h = PetRuntimeTests.Harness()
        let permission = AccessibilityPermissionStub()
        let model = SettingsModel(
            runtime: h.runtime, preferences: h.preferences, loginService: LoginService(),
            accessibilityPermission: permission)
        model.refreshWindowPermissionStatus()
        #expect(permission.trustChecks == 0)
        #expect(permission.promptCalls == 0)
        model.setWindowInteractionEnabled(true)
        #expect(permission.trustChecks > 0)
        #expect(permission.promptCalls == 0)
        #expect(permission.settingsCalls == 0)
        #expect(model.isWindowPermissionConfirmationPresented)
        model.cancelWindowPermissionRequest()
        #expect(!h.preferences.isWindowInteractionEnabled)
        #expect(permission.promptCalls == 0)
        h.runtime.stop()
    }

    @Test func explicitLoginToggleReflectsActualFailureAndCanRecover() {
        let h = PetRuntimeTests.Harness()
        let login = LoginService()
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: login)
        login.failure = .registrationFailed("Signature rejected")
        model.setLaunchAtLogin(true)
        #expect(model.loginStatus == .disabled)
        #expect(model.loginError == .registrationFailed("Signature rejected"))
        #expect(login.changes == [true])
        login.failure = nil
        model.setLaunchAtLogin(true)
        #expect(model.loginStatus == .enabled)
        #expect(model.loginError == nil)
        login.failure = .unregistrationFailed("Service unavailable")
        model.setLaunchAtLogin(false)
        #expect(model.loginStatus == .enabled)
        #expect(model.loginError == .unregistrationFailed("Service unavailable"))
        login.failure = nil
        model.setLaunchAtLogin(false)
        #expect(model.loginStatus == .disabled)
        #expect(model.loginError == nil)
        #expect(login.changes == [true, true, false, false])
    }

    @Test func modelAppliesSettingsAndKeepsMenuIntentInSync() {
        let h = PetRuntimeTests.Harness()
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: LoginService())
        model.setScale(1.4)
        model.setSpeed(1.8)
        model.setAutonomyEnabled(true)
        model.setJumpsEnabled(false)
        model.setRestEnabled(false)
        model.setExpressionsEnabled(false)
        model.setDockOffsetAdjustment(17)
        model.setPaused(true)
        model.setHidden(true)
        #expect(
            h.preferences.petSettings
                == PetSettings(
                    scale: 1.4, speed: 1.8,
                    behavior: AutonomySettings(
                        isEnabled: true, jumpsEnabled: false, restEnabled: false, expressionsEnabled: false)))
        #expect(model.petSettings == h.runtime.petSettings)
        #expect(model.dockOffsetAdjustment == 17)
        #expect(model.userIntent == UserIntent(isPaused: true, isHidden: true))
        h.runtime.setPaused(false)
        h.runtime.setHidden(false)
        #expect(model.userIntent == UserIntent())
    }

    @Test func restoreDefaultsUpdatesRuntimeAndUnregistersOnlyAsExplicitAction() {
        let h = PetRuntimeTests.Harness()
        let login = LoginService()
        login.status = .enabled
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: login)
        model.setScale(0.5)
        model.setSpeed(2)
        model.setPaused(true)
        model.setHidden(true)
        model.setDockOffsetAdjustment(-40)
        #expect(login.changes.isEmpty)
        model.restoreDefaults()
        #expect(model.petSettings == PetSettings())
        #expect(model.userIntent == UserIntent())
        #expect(model.dockOffsetAdjustment == 0)
        #expect(h.runtime.petSettings == PetSettings())
        #expect(h.runtime.userIntent == UserIntent())
        #expect(model.loginStatus == .disabled)
        #expect(login.changes == [false])
        model.restoreDefaults()
        #expect(login.changes == [false])
    }

    @Test func restoreKeepsLoginFailureVisibleWhileRestoringLocalChoices() {
        let h = PetRuntimeTests.Harness()
        let login = LoginService()
        login.status = .requiresApproval
        login.failure = .unregistrationFailed("Try again")
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: login)
        model.setScale(0.5)
        model.restoreDefaults()
        #expect(model.petSettings.scale == 1)
        #expect(model.loginStatus == .requiresApproval)
        #expect(model.loginError == .unregistrationFailed("Try again"))
        #expect(login.changes == [false])
    }
    @Test(arguments: [false, true])
    func sharedDockOffsetSurvivesInterleavedSettingsDebugAndRestore(debugFirst: Bool) {
        let h = PetRuntimeTests.Harness()
        let login = LoginService()
        let model = SettingsModel(runtime: h.runtime, preferences: h.preferences, loginService: login)
        func expectOffset(_ expected: Double) {
            #expect(model.dockOffsetAdjustment == expected)
            #expect(h.runtime.dockOffsetAdjustment == expected)
            #expect(h.preferences.dockOffsetAdjustment == expected)
        }
        expectOffset(0)
        if debugFirst {
            model.adjustDockOffset(by: 10)
        } else {
            model.setDockOffsetAdjustment(10)
        }
        expectOffset(10)
        if debugFirst {
            model.setDockOffsetAdjustment(11)
        } else {
            model.adjustDockOffset(by: 1)
        }
        expectOffset(11)
        model.restoreDefaults()
        expectOffset(0)
        model.adjustDockOffset(by: -1)
        expectOffset(-1)
        #expect(login.changes.isEmpty)
    }

}
