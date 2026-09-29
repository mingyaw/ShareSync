import SwiftUI

@main
struct ShareSyncMessagesBridgeApp: App {
    @StateObject private var model = MessageBridgePermissionViewModel()

    var body: some Scene {
        WindowGroup {
            MessageBridgePermissionView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
