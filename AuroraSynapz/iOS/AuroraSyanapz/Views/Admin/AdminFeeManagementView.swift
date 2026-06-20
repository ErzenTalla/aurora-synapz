import SwiftUI

struct AdminFeeManagementView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var preview: FeePreviewResult?
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var isCollecting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Fees are collected automatically on the 1st of each month — monthly charge = annual rate ÷ 12, deducted from each client's portfolio. Default rate: 1.5% per year.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted2)
                                .padding(14)
                                .background(Theme.gold.opacity(0.06))
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.12), lineWidth: 1))
                                .padding(.horizontal)

                            // Preview / collect
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Upcoming Fee Preview")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)
                                    Spacer()
                                    Button { Task { await loadPreview() } } label: {
                                        Image(systemName: "arrow.clockwise").foregroundStyle(Theme.gold)
                                    }
                                }

                                if let message {
                                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.green)
                                }

                                if let preview {
                                    Text("Total: \(preview.collected.asCurrency()) across \(preview.clients.count) client\(preview.clients.count == 1 ? "" : "s")")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.cream)

                                    VStack(spacing: 0) {
                                        ForEach(preview.clients) { c in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(c.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cream)
                                                    Text("\((c.feeRate * 100).formatted())% p.a.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                                                }
                                                Spacer()
                                                Text(c.feeAmount.asCurrencyPrecise())
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(Theme.gold)
                                            }
                                            .padding(.vertical, 8)
                                            if c.id != preview.clients.last?.id {
                                                Divider().background(Theme.gold.opacity(0.08))
                                            }
                                        }
                                    }
                                }

                                Button {
                                    Task { await collectNow() }
                                } label: {
                                    HStack {
                                        if isCollecting { ProgressView().tint(Theme.navy) }
                                        else { Text("COLLECT FEES NOW").font(.system(size: 11, weight: .bold)).tracking(1) }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Theme.gold)
                                    .foregroundStyle(Theme.navy)
                                }
                                .disabled(isCollecting)
                            }
                            .padding(16)
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)

                            // Per-client fee rate editor
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Client Fee Rates")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    ForEach(users.filter { $0.role == "client" }) { u in
                                        FeeRateRow(user: u, onSave: { rate in
                                            Task { await setFeeRate(userId: u.id, rate: rate) }
                                        })
                                        if u.id != users.last?.id {
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
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle("Fee Management")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await loadAll() }
    }

    func loadAll() async {
        isLoading = true
        async let p = loadPreview()
        async let u = loadUsers()
        _ = await (p, u)
        isLoading = false
    }

    func loadPreview() async {
        guard let token = auth.token else { return }
        preview = try? await APIService.shared.fetchFeePreview(token: token)
    }

    func loadUsers() async {
        guard let token = auth.token else { return }
        if let u = try? await APIService.shared.fetchAdminUsers(token: token) { users = u }
    }

    func collectNow() async {
        guard let token = auth.token else { return }
        isCollecting = true
        do {
            let result = try await APIService.shared.collectFees(token: token)
            message = "\(result.collected.asCurrency()) collected from \(result.clients.count) client\(result.clients.count == 1 ? "" : "s")."
            await loadPreview()
        } catch {
            message = error.localizedDescription
        }
        isCollecting = false
    }

    func setFeeRate(userId: Int, rate: Double) async {
        guard let token = auth.token else { return }
        try? await APIService.shared.setFeeRate(userId: userId, rate: rate, token: token)
        await loadUsers()
    }
}

struct FeeRateRow: View {
    let user: AdminUser
    let onSave: (Double) -> Void
    @State private var rateText: String = ""
    @State private var isEditing = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cream)
                Text(user.email).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if isEditing {
                TextField("1.5", text: $rateText)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .foregroundStyle(Theme.cream)
                    .padding(8)
                    .background(Theme.navyM.opacity(0.5))
                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                Button("Save") {
                    if let pct = Double(rateText) { onSave(pct / 100) }
                    isEditing = false
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.gold)
            } else {
                Button {
                    rateText = String(format: "%.2f", (user.feeRate ?? 0.015) * 100)
                    isEditing = true
                } label: {
                    Text("\(((user.feeRate ?? 0.015) * 100).formatted())% p.a.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(14)
    }
}
