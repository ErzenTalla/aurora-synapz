import SwiftUI

struct HoldingsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var holdings: [Holding] = []
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
                } else if holdings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.muted)
                        Text("No holdings found.")
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    List(holdings) { h in
                        HoldingRow(holding: h)
                            .listRowBackground(Theme.navy)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Holdings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(holdings.count) position\(holdings.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
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
            holdings = try await APIService.shared.fetchHoldings(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct HoldingRow: View {
    let holding: Holding

    var assetColor: Color {
        switch holding.assetClass {
        case "Equity":       return Theme.green
        case "Fixed Income": return Theme.blue
        case "Alternative":  return Theme.gold
        default:             return Theme.muted2
        }
    }

    var totalGain: Double { holding.totalGain ?? (holding.shares * (holding.price - holding.avgCost)) }
    var totalGainPct: Double { holding.totalGainPct ?? (holding.avgCost > 0 ? (holding.price - holding.avgCost) / holding.avgCost * 100 : 0) }
    var marketValue: Double { holding.marketValue ?? (holding.shares * holding.price) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(holding.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.gold.opacity(0.12))
                            .foregroundStyle(Theme.gold)
                        Text(holding.assetClass)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(assetColor.opacity(0.12))
                            .foregroundStyle(assetColor)
                    }
                    Text(holding.name)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted2)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(marketValue.asCurrency())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                    Text(totalGainPct.asPct())
                        .font(.system(size: 12))
                        .foregroundStyle(totalGainPct.color())
                }
            }
            .padding(.vertical, 12)

            Divider().background(Theme.gold.opacity(0.08))

            HStack {
                DetailItem(label: "Shares", value: String(format: "%.2f", holding.shares))
                Spacer()
                DetailItem(label: "Price", value: holding.price.asCurrencyPrecise())
                Spacer()
                DetailItem(label: "Avg Cost", value: holding.avgCost.asCurrencyPrecise())
                Spacer()
                DetailItem(label: "Day", value: holding.dayChange.asCurrencyPrecise(), color: holding.dayChange.color())
            }
            .padding(.vertical, 10)
        }
    }
}

struct DetailItem: View {
    let label: String
    let value: String
    var color: Color = Theme.cream

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
        }
    }
}
