import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var email    = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            Theme.navy3.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo area
                    VStack(spacing: 16) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.gold)
                        Text("AURORA SYNAPZ")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(Theme.gold)
                        Text("Asset Management")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 48)

                    // Form card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CLIENT PORTAL")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(3)
                            .foregroundStyle(Theme.gold)
                            .padding(.bottom, 8)

                        Text("Welcome Back")
                            .font(.custom("Georgia", size: 30))
                            .foregroundStyle(Theme.cream)
                            .padding(.bottom, 4)

                        Text("Sign in to access your account")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .padding(.bottom, 32)

                        if let err = auth.errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(Theme.red)
                                Text(err)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.red)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.red.opacity(0.1))
                            .overlay(Rectangle().stroke(Theme.red.opacity(0.3), lineWidth: 1))
                            .padding(.bottom, 20)
                        }

                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EMAIL ADDRESS")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.muted)
                            TextField("", text: $email, prompt: Text("you@example.com").foregroundStyle(Theme.muted.opacity(0.5)))
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundStyle(Theme.cream)
                                .padding(14)
                                .background(Theme.navyM.opacity(0.5))
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.bottom, 16)

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PASSWORD")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.muted)
                            SecureField("", text: $password, prompt: Text("••••••••").foregroundStyle(Theme.muted.opacity(0.5)))
                                .foregroundStyle(Theme.cream)
                                .padding(14)
                                .background(Theme.navyM.opacity(0.5))
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.bottom, 28)

                        // Sign in button
                        Button {
                            Task { await auth.login(email: email.trimmingCharacters(in: .whitespaces), password: password) }
                        } label: {
                            HStack {
                                if auth.isLoading {
                                    ProgressView().tint(Theme.navy)
                                } else {
                                    Text("SIGN IN TO PORTAL")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.gold)
                            .foregroundStyle(Theme.navy)
                        }
                        .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1)
                    }
                    .padding(28)
                    .background(Theme.navy)
                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
