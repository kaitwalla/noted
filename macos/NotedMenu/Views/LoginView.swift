import SwiftUI
import AppKit

struct LoginView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showServerConfig = false
    @State private var apiURL = APIService.apiURL

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    showServerConfig.toggle()
                } label: {
                    Image(systemName: "server.rack")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showServerConfig, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                        TextField("API URL", text: $apiURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 250)
                            .onSubmit {
                                saveAPIURL()
                            }
                        HStack {
                            Button("Reset") {
                                apiURL = APIService.defaultURL
                                saveAPIURL()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            Spacer()
                            Button("Save") {
                                saveAPIURL()
                                showServerConfig = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding()
                }
            }

            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Noted")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .onSubmit {
                        login()
                    }
            }

            if let error = appViewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: login) {
                if appViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || appViewModel.isLoading)

            Divider()
                .padding(.top, 8)

            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Noted")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 280)
    }

    private func login() {
        Task {
            await appViewModel.login(email: email, password: password)
        }
    }

    private func saveAPIURL() {
        let trimmed = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, URL(string: trimmed) != nil {
            APIService.apiURL = trimmed
        }
    }
}
