import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        if auth.isLoggedIn {
            if auth.isAdmin {
                AdminTabView()
            } else {
                ClientTabView()
            }
        } else {
            LoginView()
        }
    }
}
