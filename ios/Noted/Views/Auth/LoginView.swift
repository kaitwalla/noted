import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.themeColors) private var colors
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo/Title
                VStack(spacing: 8) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                    Text("Noted")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(colors.text)
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
                        .background(colors.secondaryBackground)
                        .cornerRadius(10)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(colors.secondaryBackground)
                        .cornerRadius(10)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(colors.error)
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
                        .foregroundStyle(colors.secondaryText)
                    + Text("Sign Up")
                        .foregroundStyle(colors.accent)
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
