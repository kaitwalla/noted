import SwiftUI

@main
struct NotedApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .themed()
                .onAppear {
                    themeManager.updateAppearance()
                }
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
