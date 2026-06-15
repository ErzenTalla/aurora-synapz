import SwiftUI

struct ClientTabView: View {
    @EnvironmentObject var auth: AuthStore

    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
                }

            HoldingsView()
                .tabItem {
                    Label("Holdings", systemImage: "chart.bar.fill")
                }

            TransactionsView()
                .tabItem {
                    Label("Activity", systemImage: "arrow.left.arrow.right")
                }

            DocumentsView()
                .tabItem {
                    Label("Documents", systemImage: "doc.text.fill")
                }

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.fill")
                }
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
