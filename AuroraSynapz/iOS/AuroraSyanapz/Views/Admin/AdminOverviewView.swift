import SwiftUI

struct AdminOverviewView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var stats: AdminStats?
    @State private var users: [AdminUser] = []
    @State private var contacts: [Contact] = []
    @State private var isLoading = true

    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = error {
                    ErrorRetryView(message: err) { Task { await loadAll() } }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Stats grid
                            if let s = stats {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    StatCard(label: "Total AUM", value: s.totalAum.asCurrency(), sub: "Across \(s.clientCount) client\(s.clientCount == 1 ? "" : "s")", subColor: Theme.muted)
                                    StatCard(label: "Active Clients", value: "\(s.clientCount)", sub: "Registered accounts", subColor: Theme.muted)
                                    StatCard(label: "Inquiries", value: "\(s.contactCount)", sub: "Form submissions", subColor: Theme.muted)
                                    StatCard(label: "Total Deposits", value: s.totalDeposits.asCurrency(), sub: "Via Stripe", subColor: Theme.muted)
                                }
                                .padding(.horizontal)
                            }


                            // Recent clients
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Clients")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)
                                    Spacer()
                                    Text("\(users.count) accounts")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.muted)
                                }
                                ForEach(users.prefix(5)) { u in
                                    AdminUserRow(user: u)
                                    if u.id != users.prefix(5).last?.id {
                                        Divider().background(Theme.gold.opacity(0.08))
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)

                            // Recent contacts
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Inquiries")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)
                                if contacts.isEmpty {
                                    Text("No contact submissions yet.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.vertical, 12)
                                } else {
                                    ForEach(contacts.prefix(3)) { c in
                                        ContactRow(contact: c)
                                        if c.id != contacts.prefix(3).last?.id {
                                            Divider().background(Theme.gold.opacity(0.08))
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)

                            Spacer(minLength: 20)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("ADMIN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.15))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .task { await loadAll() }
    }

    func loadAll() async {
        guard let token = auth.token else { return }
        async let s = APIService.shared.fetchAdminStats(token: token)
        async let u = APIService.shared.fetchAdminUsers(token: token)
        async let c = APIService.shared.fetchAdminContacts(token: token)
        do {
            let (st, us, co) = try await (s, u, c)
            stats = st; users = us; contacts = co
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct AdminUserRow: View {
    let user: AdminUser

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(user.role == "admin" ? Theme.gold.opacity(0.2) : Theme.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(user.name.prefix(2).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(user.role == "admin" ? Theme.gold : Theme.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(user.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                Text(user.email)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let val = user.totalValue {
                    Text(val.asCurrency())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                }
                Text(user.role.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(user.role == "admin" ? Theme.gold.opacity(0.15) : Theme.blue.opacity(0.12))
                    .foregroundStyle(user.role == "admin" ? Theme.gold : Theme.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
