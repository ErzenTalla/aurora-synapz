import SwiftUI

struct AdminTabView: View {
    var body: some View {
        TabView {
            AdminOverviewView()
                .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }

            AdminClientsView()
                .tabItem { Label("Clients", systemImage: "person.2.fill") }

            AdminContactsView()
                .tabItem { Label("Contacts", systemImage: "envelope.fill") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.fill") }
        }
        .tint(Theme.gold)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Theme.navy)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
