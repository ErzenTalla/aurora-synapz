import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isLoggedIn {
                if !auth.isUnlocked {
                    LockView()
                } else if auth.isAdmin {
                    AdminTabView()
                } else {
                    ClientTabView()
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                auth.lockIfNeeded()
            }
        }
    }
}
