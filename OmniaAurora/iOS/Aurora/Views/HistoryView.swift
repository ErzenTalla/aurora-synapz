import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var summaries: [BriefingSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selected: BriefingResponse?
    @State private var isLoadingDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(Theme.red).padding()
                } else if summaries.isEmpty {
                    Text("No briefings saved yet.").foregroundStyle(Theme.muted).padding()
                } else {
                    List(summaries) { summary in
                        Button {
                            Task { await loadDetail(summary.date) }
                        } label: {
                            Text(summary.date).foregroundStyle(Theme.cream)
                        }
                        .listRowBackground(Theme.navy2)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("History")
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .sheet(item: $selected) { briefing in
                detailSheet(briefing)
            }
        }
        .task { await load() }
    }

    private func detailSheet(_ briefing: BriefingResponse) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingDetail {
                        ProgressView().tint(Theme.gold)
                    }
                    Text(briefing.briefing)
                        .foregroundStyle(Theme.cream)
                }
                .padding()
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle(briefing.date)
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        speech.speak(briefing.briefing)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.gold)
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            summaries = try await APIService.shared.listBriefings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDetail(_ date: String) async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }
        do {
            selected = try await APIService.shared.fetchBriefing(date: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
