import SwiftUI

@main
struct ShareSyncMacApp: App {
    @StateObject private var syncModel = MacPhotoSyncViewModel()

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environmentObject(syncModel)
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 960, height: 650)

        Settings {
            MacSettingsView()
                .environmentObject(syncModel)
                .frame(width: 520, height: 390)
        }
    }
}
