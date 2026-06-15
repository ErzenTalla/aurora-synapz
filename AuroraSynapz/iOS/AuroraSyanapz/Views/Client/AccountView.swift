import SwiftUI

struct AccountView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var showChangePw = false
    @State private var currentPw = ""
    @State private var newPw = ""
    @State private var confirmPw = ""
    @State private var pwError: String?
    @State private var pwSuccess = false
    @State private var isUpdating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Avatar
                        VStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Theme.gold).frame(width: 72, height: 72)
                                Text(initials)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Theme.navy)
                            }
                            Text(auth.user?.name ?? "")
                                .font(.custom("Georgia", size: 22))
                                .foregroundStyle(Theme.cream)
                            Text(auth.user?.email ?? "")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                            Text("PRIVATE CLIENT")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Theme.gold.opacity(0.12))
                                .foregroundStyle(Theme.gold)
                        }
                        .padding(.top, 20)

                        // Change password section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SECURITY")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(Theme.muted)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                Button {
                                    withAnimation { showChangePw.toggle() }
                                } label: {
                                    HStack {
                                        Image(systemName: "lock.fill").foregroundStyle(Theme.gold)
                                        Text("Change Password").foregroundStyle(Theme.cream)
                                        Spacer()
                                        Image(systemName: showChangePw ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    .padding(16)
                                }

                                if showChangePw {
                                    VStack(spacing: 14) {
                                        Divider().background(Theme.gold.opacity(0.1))

                                        if let err = pwError {
                                            Text(err)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.red)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 16)
                                        }
                                        if pwSuccess {
                                            Text("Password updated successfully.")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.green)
                                                .padding(.horizontal, 16)
                                        }

                                        PwField(label: "Current Password", text: $currentPw)
                                        PwField(label: "New Password", text: $newPw)
                                        PwField(label: "Confirm New Password", text: $confirmPw)

                                        Button {
                                            Task { await updatePassword() }
                                        } label: {
                                            HStack {
                                                if isUpdating { ProgressView().tint(Theme.navy) }
                                                else { Text("UPDATE PASSWORD").font(.system(size: 11, weight: .bold)).tracking(2) }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(14)
                                            .background(Theme.gold)
                                            .foregroundStyle(Theme.navy)
                                        }
                                        .disabled(isUpdating)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 16)
                                    }
                                }
                            }
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)
                        }

                        // Sign out
                        Button {
                            auth.logout()
                        } label: {
                            Text("SIGN OUT")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.clear)
                                .foregroundStyle(Theme.muted)
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    var initials: String {
        (auth.user?.name ?? "").split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    func updatePassword() async {
        pwError = nil; pwSuccess = false
        guard newPw == confirmPw else { pwError = "New passwords do not match"; return }
        guard newPw.count >= 8 else { pwError = "New password must be at least 8 characters"; return }
        guard let token = auth.token else { return }
        isUpdating = true
        do {
            try await APIService.shared.changePassword(current: currentPw, new: newPw, token: token)
            pwSuccess = true
            currentPw = ""; newPw = ""; confirmPw = ""
            withAnimation { showChangePw = false }
        } catch {
            pwError = error.localizedDescription
        }
        isUpdating = false
    }
}

struct PwField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 16)
            SecureField("••••••••", text: $text)
                .foregroundStyle(Theme.cream)
                .padding(12)
                .background(Theme.navyM.opacity(0.5))
                .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 16)
        }
    }
}
