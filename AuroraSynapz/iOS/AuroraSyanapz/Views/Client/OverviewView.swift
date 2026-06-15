import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var portfolio: Portfolio?
    @State private var performance: [PerformancePoint] = []
    @State private var allocation: [AllocationItem] = []
    @State private var transactions: [Transaction] = []
    @State private var selectedRange = "1Y"
    @State private var isLoading = true
    @State private var error: String?

    let ranges = ["1M", "3M", "6M", "1Y", "ALL"]
    let allocColors: [Color] = [Theme.gold, Theme.green, Theme.blue, Theme.gold2, Theme.red]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.red)
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Try Again") { Task { await loadAll() } }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.4), lineWidth: 1))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let p = portfolio {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    StatCard(label: "Portfolio Value", value: p.totalValue.asCurrency(), sub: "Since \(p.inceptionDate)", subColor: Theme.muted)
                                    StatCard(label: "Today's Change", value: p.dayChange.asCurrency(), sub: p.dayChangePct.asPct(), subColor: p.dayChangePct.color())
                                    StatCard(label: "YTD Return", value: p.ytdReturn.asCurrency(), sub: p.ytdReturnPct.asPct(), subColor: p.ytdReturnPct.color())
                                    StatCard(label: "Cash Balance", value: p.cashBalance.asCurrency(), sub: p.totalValue > 0 ? "\(String(format: "%.1f", (p.cashBalance / p.totalValue) * 100))% of portfolio" : "—", subColor: Theme.muted)
                                }
                                .padding(.horizontal)
                            }

                            // Performance chart
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Portfolio Performance")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)

                                HStack(spacing: 6) {
                                    ForEach(ranges, id: \.self) { r in
                                        Button(r) {
                                            selectedRange = r
                                            Task { await loadPerformance() }
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 5)
                                        .background(selectedRange == r ? Theme.gold.opacity(0.15) : Color.clear)
                                        .foregroundStyle(selectedRange == r ? Theme.gold : Theme.muted)
                                        .overlay(Rectangle().stroke(selectedRange == r ? Theme.gold.opacity(0.4) : Theme.gold.opacity(0.15), lineWidth: 1))
                                    }
                                }

                                if !performance.isEmpty {
                                    Chart(performance) { point in
                                        AreaMark(x: .value("Date", point.dateValue), y: .value("Value", point.value))
                                            .foregroundStyle(LinearGradient(colors: [Theme.gold.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                                        LineMark(x: .value("Date", point.dateValue), y: .value("Value", point.value))
                                            .foregroundStyle(Theme.gold)
                                            .lineStyle(StrokeStyle(lineWidth: 2))
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .month, count: 2)) { val in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cream.opacity(0.06))
                                            AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(Theme.muted)
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .trailing) { val in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Theme.cream.opacity(0.06))
                                            AxisValueLabel {
                                                if let v = val.as(Double.self) {
                                                    Text(v >= 1000 ? "$\(Int(v / 1000))K" : "$\(Int(v))")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(Theme.muted)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 200)
                                } else {
                                    Text("No performance data available.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.muted)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .frame(height: 100)
                                }
                            }
                            .padding()
                            .background(Theme.navy)
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)

                            // Asset allocation
                            if !allocation.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Asset Allocation")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)

                                    HStack(alignment: .top, spacing: 20) {
                                        Chart(allocation) { item in
                                            SectorMark(angle: .value("Value", item.value), innerRadius: .ratio(0.65))
                                                .foregroundStyle(allocColors[allocation.firstIndex(where: { $0.id == item.id }) ?? 0 % allocColors.count])
                                        }
                                        .frame(width: 130, height: 130)

                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(Array(allocation.enumerated()), id: \.1.id) { i, item in
                                                HStack(spacing: 10) {
                                                    RoundedRectangle(cornerRadius: 2)
                                                        .fill(allocColors[i % allocColors.count])
                                                        .frame(width: 10, height: 10)
                                                    Text(item.label)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(Theme.muted2)
                                                    Spacer()
                                                    Text("\(String(format: "%.1f", item.pct))%")
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(Theme.cream)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding()
                                .background(Theme.navy)
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal)
                            }

                            // Recent activity
                            if !transactions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent Activity")
                                        .font(.custom("Georgia", size: 18))
                                        .foregroundStyle(Theme.cream)
                                    ForEach(transactions.prefix(5)) { tx in
                                        TransactionRow(tx: tx)
                                    }
                                }
                                .padding()
                                .background(Theme.navy)
                                .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal)
                            }

                            Spacer(minLength: 20)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable { await loadAll() }
                }
            }
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(auth.user?.name.components(separatedBy: " ").first ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .task { await loadAll() }
    }

    func loadAll() async {
        guard let token = auth.token else { return }
        isLoading = true
        error = nil
        async let p  = APIService.shared.fetchOverview(token: token)
        async let pf = APIService.shared.fetchPerformance(token: token, range: selectedRange)
        async let al = APIService.shared.fetchAllocation(token: token)
        async let tx = APIService.shared.fetchTransactions(token: token, limit: 10)
        do {
            let (port, perf, alloc, txs) = try await (p, pf, al, tx)
            portfolio    = port
            performance  = perf
            allocation   = alloc
            transactions = txs
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadPerformance() async {
        guard let token = auth.token else { return }
        if let perf = try? await APIService.shared.fetchPerformance(token: token, range: selectedRange) {
            performance = perf
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let sub: String
    let subColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.custom("Georgia", size: 22))
                .foregroundStyle(Theme.cream)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(subColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.navy)
        .overlay(
            VStack {
                Rectangle().fill(LinearGradient(colors: [Theme.gold, .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 2)
                Spacer()
            }
        )
        .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
    }
}

struct TransactionRow: View {
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
        HStack(spacing: 12) {
            Text(tx.type)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(typeColor.opacity(0.15))
                .foregroundStyle(typeColor)

            VStack(alignment: .leading, spacing: 2) {
                if let symbol = tx.symbol {
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                    Text(tx.name ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text(tx.note ?? tx.type)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cream)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountSign + tx.amount.asCurrencyPrecise())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(amountColor)
                Text(tx.createdAt.prefix(10))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }
}
