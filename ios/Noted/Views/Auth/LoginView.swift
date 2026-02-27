import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo/Title
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundStyle(.accent)
                    Text("Noted")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                Spacer()

                // Form
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await viewModel.login()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading)
                }

                Spacer()

                // Register link
                Button {
                    showRegister = true
                } label: {
                    Text("Don't have an account? ")
                        .foregroundStyle(.secondary)
                    + Text("Sign Up")
                        .foregroundStyle(.accent)
                }
                .padding(.bottom)
            }
            .padding(.horizontal, 32)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
