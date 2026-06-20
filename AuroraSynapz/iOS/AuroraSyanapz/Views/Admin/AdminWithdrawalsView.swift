import SwiftUI

struct AdminWithdrawalsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var withdrawals: [WithdrawalRequest] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("When a client requests a withdrawal, their units are redeemed immediately and Alpaca sell orders are placed. Confirm here once the bank wire has been sent.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted2)
                                .padding(14)
                                .background(Theme.gold.opacity(0.06))
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.12), lineWidth: 1))
                                .padding(.horizontal)

                            if withdrawals.isEmpty {
                                Text("No withdrawal requests yet.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(withdrawals) { w in
                                        AdminWithdrawalRow(w: w, onAction: { status in
                                            Task { await updateStatus(w, status: status) }
                                        })
                                        if w.id != withdrawals.last?.id {
                                            Divider().background(Theme.gold.opacity(0.08))
                                        }
                                    }
                                }
                                .background(Theme.navy)
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal)
                            }
                            Spacer(minLength: 30)
                        }
                        .padding(.top, 12)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Withdrawals")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        if let w = try? await APIService.shared.fetchAdminWithdrawals(token: token) { withdrawals = w }
        isLoading = false
    }

    func updateStatus(_ w: WithdrawalRequest, status: String) async {
        guard let token = auth.token else { return }
        try? await APIService.shared.updateWithdrawalStatus(id: w.id, status: status, token: token)
        await load()
    }
}

struct AdminWithdrawalRow: View {
    let w: WithdrawalRequest
    let onAction: (String) -> Void

    var statusColor: Color {
        switch w.status {
        case "pending":   return Theme.gold
        case "approved":  return Theme.blue
        case "processed": return Theme.green
        case "rejected":  return Theme.red
        default:          return Theme.muted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(w.name ?? "Unknown").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.cream)
                    Text(w.email ?? "").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(w.amount.asCurrency()).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.cream)
                    Text(w.status.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                }
            }

            if w.status == "pending" {
                HStack(spacing: 10) {
                    Button("Mark Processed") { onAction("processed") }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.gold)
                    Button("Reject") { onAction("rejected") }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .overlay(Rectangle().stroke(Theme.red.opacity(0.4), lineWidth: 1))
                }
            } else if let notes = w.notes {
                Text(notes).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
    }
}
