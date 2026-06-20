import SwiftUI

struct AdminDepositRequestsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var requests: [DepositRequest] = []
    @State private var investCash: InvestCashStatus?
    @State private var investAmountText = ""
    @State private var isLoading = true
    @State private var isInvesting = false
    @State private var investError: String?
    @State private var investMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Invest panel
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Invest Available Cash")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)
                                    Spacer()
                                    Button {
                                        Task { await loadInvestCash() }
                                    } label: {
                                        Image(systemName: "arrow.clockwise").foregroundStyle(Theme.gold)
                                    }
                                }

                                if let investCash {
                                    Text(investCash.configured
                                        ? "Uninvested cash in Alpaca: \(investCash.cash.asCurrency())"
                                        : "Alpaca not configured")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                }

                                if let investError {
                                    Text(investError).font(.system(size: 12)).foregroundStyle(Theme.red)
                                }
                                if let investMessage {
                                    Text(investMessage).font(.system(size: 12)).foregroundStyle(Theme.green)
                                }

                                TextField("Amount to invest", text: $investAmountText)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(Theme.cream)
                                    .padding(12)
                                    .background(Theme.navyM.opacity(0.5))
                                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))

                                Button {
                                    Task { await invest() }
                                } label: {
                                    HStack {
                                        if isInvesting { ProgressView().tint(Theme.navy) }
                                        else { Text("INVEST (40% SPY / 30% BND / 20% GLD)").font(.system(size: 11, weight: .bold)).tracking(1) }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Theme.gold)
                                    .foregroundStyle(Theme.navy)
                                }
                                .disabled(isInvesting)
                            }
                            .padding(16)
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)

                            // Requests list
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("All Requests")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)
                                    Spacer()
                                    Text("\(requests.count) request\(requests.count == 1 ? "" : "s")")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                }
                                .padding(.horizontal)

                                if requests.isEmpty {
                                    Text("No deposit requests yet.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(requests) { r in
                                            AdminDepositRequestRow(r: r, onAction: { status in
                                                Task { await updateStatus(r, status: status) }
                                            })
                                            if r.id != requests.last?.id {
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
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle("Deposit Requests")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadAll() }
    }

    func loadAll() async {
        isLoading = true
        async let r = loadRequests()
        async let c = loadInvestCash()
        _ = await (r, c)
        isLoading = false
    }

    func loadRequests() async {
        guard let token = auth.token else { return }
        if let r = try? await APIService.shared.fetchAdminDepositRequests(token: token) { requests = r }
    }

    func loadInvestCash() async {
        guard let token = auth.token else { return }
        investError = nil
        do {
            let status = try await APIService.shared.fetchInvestCash(token: token)
            investCash = status
            if investAmountText.isEmpty && status.cash > 0 {
                investAmountText = String(format: "%.0f", status.cash)
            }
        } catch {
            investError = error.localizedDescription
        }
    }

    func invest() async {
        investError = nil
        investMessage = nil
        guard let amount = Double(investAmountText), amount > 0 else {
            investError = "Enter a valid amount"
            return
        }
        guard let token = auth.token else { return }
        isInvesting = true
        do {
            let result = try await APIService.shared.investCash(amount: amount, token: token)
            investMessage = "\(result.amount.asCurrency()) submitted across \(result.trades.count) orders."
            await loadInvestCash()
        } catch {
            investError = error.localizedDescription
        }
        isInvesting = false
    }

    func updateStatus(_ r: DepositRequest, status: String) async {
        guard let token = auth.token else { return }
        try? await APIService.shared.updateDepositRequestStatus(id: r.id, status: status, token: token)
        await loadRequests()
    }
}

struct AdminDepositRequestRow: View {
    let r: DepositRequest
    let onAction: (String) -> Void
    @EnvironmentObject var auth: AuthStore
    @State private var proofFileURL: URL?
    @State private var isDownloadingProof = false

    var statusColor: Color {
        switch r.status {
        case "pending":  return Theme.gold
        case "received": return Theme.green
        case "rejected": return Theme.red
        default:         return Theme.muted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name ?? "Unknown").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.cream)
                    Text(r.email ?? "").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(r.amount.asCurrency()).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.cream)
                    Text(r.status.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .foregroundStyle(statusColor)
                }
            }

            if let filename = r.filename {
                if let proofFileURL {
                    ShareLink(item: proofFileURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "paperclip")
                            Text(filename)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                    }
                } else {
                    Button {
                        Task { await downloadProof(filename: filename) }
                    } label: {
                        HStack(spacing: 6) {
                            if isDownloadingProof { ProgressView().tint(Theme.gold) }
                            else { Image(systemName: "paperclip") }
                            Text(filename)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gold)
                    }
                    .disabled(isDownloadingProof)
                }
            }

            if r.status == "pending" {
                HStack(spacing: 10) {
                    Button("Mark Received") { onAction("received") }
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
            } else if let notes = r.notes {
                Text(notes).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
    }

    func downloadProof(filename: String) async {
        guard let token = auth.token else { return }
        isDownloadingProof = true
        if let data = try? await APIService.shared.downloadAdminDepositProof(id: r.id, token: token) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? data.write(to: url, options: .atomic)
            proofFileURL = url
        }
        isDownloadingProof = false
    }
}
