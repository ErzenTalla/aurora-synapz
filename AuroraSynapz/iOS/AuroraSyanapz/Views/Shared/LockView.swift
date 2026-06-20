import SwiftUI

struct LockView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.navy3.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.gold)
                Text("Aurora Synapz")
                    .font(.custom("Georgia", size: 22))
                    .foregroundStyle(Theme.cream)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await authenticate() }
                } label: {
                    Text("UNLOCK WITH FACE ID")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Theme.gold)
                        .foregroundStyle(Theme.navy)
                }
            }
        }
        .task { await authenticate() }
    }

    private func authenticate() async {
        let ok = await BiometricAuthenticator.authenticate()
        await MainActor.run {
            if ok {
                auth.isUnlocked = true
            } else {
                errorMessage = "Authentication failed. Tap to try again."
            }
        }
    }
}
