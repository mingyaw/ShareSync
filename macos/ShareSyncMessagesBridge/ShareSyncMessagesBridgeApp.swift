import SwiftUI

@main
struct ShareSyncMessagesBridgeApp: App {
    @StateObject private var model = MessageBridgePermissionViewModel()

    var body: some Scene {
        WindowGroup {
            ScrollView {
                MessageBridgePermissionView()
                    .environmentObject(model)
            }
            .frame(minHeight: 640)
        }
        .defaultSize(width: 576, height: 760)
    }
}
