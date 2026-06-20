import SwiftUI

struct WithdrawView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var portfolio: Portfolio?
    @State private var withdrawals: [WithdrawalRequest] = []
    @State private var amountText = ""
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = loadError {
                    ErrorRetryView(message: err) { Task { await load() } }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let p = portfolio {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    StatCard(label: "Available Balance", value: p.totalValue.asCurrency(), sub: "Cash: \(p.cashBalance.asCurrency())", subColor: Theme.muted)
                                    StatCard(label: "Minimum Withdrawal", value: "$100", sub: "Processing 2-5 business days", subColor: Theme.muted)
                                }
                                .padding(.horizontal)
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                Text("New Withdrawal Request")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)

                                if let error {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.red)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("WITHDRAWAL AMOUNT (USD)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Theme.muted)
                                    TextField("e.g. 500", text: $amountText)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(Theme.cream)
                                        .padding(12)
                                        .background(Theme.navyM.opacity(0.5))
                                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                                }

                                Text("Your request will be reviewed by your advisor. Once approved, funds will be transferred to your registered bank account within 2-5 business days.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted2)
                                    .padding(12)
                                    .background(Theme.gold.opacity(0.06))
                                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.12), lineWidth: 1))

                                Button {
                                    Task { await submit() }
                                } label: {
                                    HStack {
                                        if isSubmitting { ProgressView().tint(Theme.navy) }
                                        else { Text("REQUEST WITHDRAWAL").font(.system(size: 11, weight: .bold)).tracking(2) }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Theme.gold)
                                    .foregroundStyle(Theme.navy)
                                }
                                .disabled(isSubmitting)
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Withdrawal History")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)
                                    .padding(.horizontal)

                                if withdrawals.isEmpty {
                                    Text("No withdrawal requests yet.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(withdrawals) { w in
                                            WithdrawalRow(w: w)
                                            if w.id != withdrawals.last?.id {
                                                Divider().background(Theme.gold.opacity(0.08))
                                            }
                                        }
                                    }
                                    .background(Theme.navy)
                                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                                    .padding(.horizontal)
                                }
                            }

                            Spacer(minLength: 30)
                        }
                        .padding(.top, 12)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Withdraw Funds")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        isLoading = true
        loadError = nil
        do {
            async let p = APIService.shared.fetchOverview(token: token)
            async let w = APIService.shared.fetchWithdrawals(token: token)
            portfolio = try await p
            withdrawals = try await w
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func submit() async {
        error = nil
        guard let amount = Double(amountText), amount >= 100 else {
            error = "Minimum withdrawal is $100"
            return
        }
        if let p = portfolio, amount > p.totalValue {
            error = "Amount exceeds your available balance of \(p.totalValue.asCurrency())"
            return
        }
        guard let token = auth.token else { return }
        isSubmitting = true
        do {
            _ = try await APIService.shared.withdraw(amount: amount, token: token)
            amountText = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}

struct WithdrawalRow: View {
    let w: WithdrawalRequest

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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(w.amount.asCurrency())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                Text(String(w.createdAt.prefix(10)))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(w.status.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(statusColor.opacity(0.12))
                .foregroundStyle(statusColor)
        }
        .padding(14)
    }
}
