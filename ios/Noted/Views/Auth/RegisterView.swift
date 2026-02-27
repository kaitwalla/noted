import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Sign up to start taking notes")
                    .foregroundStyle(.secondary)
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
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
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
                        await viewModel.register()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.errorMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView(viewModel: AuthViewModel())
    }
}
