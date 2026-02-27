import SwiftUI

struct ContentView: View {
    @State private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView(authViewModel: authViewModel)
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .task {
            await authViewModel.checkAuthStatus()
        }
    }
}

#Preview {
    ContentView()
}
