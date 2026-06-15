import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var transactions: [Transaction] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = error {
                    ErrorRetryView(message: err) { Task { await load() } }
                } else if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.muted)
                        Text("No transactions yet.")
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    List(transactions) { tx in
                        TransactionDetailRow(tx: tx)
                            .listRowBackground(Theme.navy)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !transactions.isEmpty {
                        Text("\(transactions.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        isLoading = true
        error = nil
        do {
            transactions = try await APIService.shared.fetchTransactions(token: token, limit: 50)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct TransactionDetailRow: View {
    let tx: Transaction

    var typeColor: Color {
        switch tx.type {
        case "BUY":      return Theme.green
        case "SELL":     return Theme.red
        case "DIVIDEND": return Theme.gold
        default:         return Theme.blue
        }
    }

    var amountSign: String {
        switch tx.type {
        case "SELL", "WITHDRAW": return "-"
        default: return "+"
        }
    }

    var amountColor: Color {
        switch tx.type {
        case "SELL", "WITHDRAW": return Theme.red
        default: return Theme.green
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(tx.type)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(typeColor.opacity(0.15))
                .foregroundStyle(typeColor)
                .frame(minWidth: 64)

            VStack(alignment: .leading, spacing: 3) {
                if let symbol = tx.symbol {
                    HStack(spacing: 6) {
                        Text(symbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.gold)
                        Text(tx.name ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.cream)
                            .lineLimit(1)
                    }
                } else {
                    Text(tx.note ?? tx.type)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cream)
                }
                if let shares = tx.shares, let price = tx.price {
                    Text("\(String(format: "%.0f", shares)) sh @ \(price.asCurrencyPrecise())")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountSign + tx.amount.asCurrencyPrecise())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(amountColor)
                Text(String(tx.createdAt.prefix(10)))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 14)
    }
}
