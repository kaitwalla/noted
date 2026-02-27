import SwiftUI

struct MainTabView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            NotebookListView()
                .tabItem {
                    Label("Notebooks", systemImage: "book.closed.fill")
                }

            TodosView()
                .tabItem {
                    Label("Todos", systemImage: "checkmark.circle")
                }

            RemindersView()
                .tabItem {
                    Label("Reminders", systemImage: "bell.fill")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SettingsView(authViewModel: authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView(authViewModel: AuthViewModel())
}
