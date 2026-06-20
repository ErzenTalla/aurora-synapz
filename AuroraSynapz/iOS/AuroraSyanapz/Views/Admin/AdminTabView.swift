import SwiftUI

struct AdminTabView: View {
    var body: some View {
        TabView {
            AdminOverviewView()
                .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }

            AdminClientsView()
                .tabItem { Label("Clients", systemImage: "person.2.fill") }

            AdminDepositRequestsView()
                .tabItem { Label("Deposits", systemImage: "arrow.down.circle.fill") }

            AdminWithdrawalsView()
                .tabItem { Label("Withdrawals", systemImage: "arrow.up.circle.fill") }

            AdminFeeManagementView()
                .tabItem { Label("Fees", systemImage: "dollarsign.circle.fill") }

            AdminDocumentsView()
                .tabItem { Label("Documents", systemImage: "doc.text.fill") }

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
