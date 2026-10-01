import SwiftUI

enum MacPreferenceKeys {
    static let keepRunning = "mac.keepRunning"
    static let automaticSync = "mac.automaticSync"
    static let syncIntervalMinutes = "mac.syncIntervalMinutes"
    static let batchLimit = "mac.batchLimit"
}

final class ShareSyncMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let defaults = UserDefaults.standard
        let keepRunning = defaults.object(forKey: MacPreferenceKeys.keepRunning) as? Bool ?? true
        return !keepRunning
    }
}

@main
struct ShareSyncMacApp: App {
    @NSApplicationDelegateAdaptor(ShareSyncMacAppDelegate.self) private var appDelegate
    @StateObject private var syncModel = MacPhotoSyncViewModel()
    @StateObject private var messageModel = MessageBridgePermissionViewModel()

    var body: some Scene {
        Window("ShareSync", id: "main") {
            MacContentView()
                .environmentObject(syncModel)
                .environmentObject(messageModel)
                .frame(minWidth: 820, minHeight: 560)
                .task {
                    messageModel.checkAccess()
                }
        }
        .defaultSize(width: 960, height: 650)

        Settings {
            MacSettingsView()
                .environmentObject(syncModel)
                .frame(width: 540, height: 520)
        }

        MenuBarExtra {
            MacMenuBarView(model: syncModel)
        } label: {
            Image(systemName: syncModel.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MacMenuBarView: View {
    @ObservedObject var model: MacPhotoSyncViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusTitle)
        Text(model.statusDetail)

        Divider()

        Button("mac.menubar.sync_now") {
            model.syncNow()
        }
        .disabled(!model.isPaired || model.isBusy)

        Button("mac.menubar.open") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }

        Button("mac.menubar.settings") {
            NSApp.activate(ignoringOtherApps: true)
            if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }

        Divider()

        Button("mac.menubar.quit") {
            NSApp.terminate(nil)
        }
    }
}
