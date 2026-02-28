import SwiftUI

@main
struct NotedApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Free up memory when app goes to background
                CoreDataStack.shared.refreshContext()
                ImageService.shared.clearMemoryCache()
            }
        }
    }
}
