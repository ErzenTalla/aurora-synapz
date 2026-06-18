import SwiftUI

struct ContentView: View {
    @StateObject private var speech = SpeechService()
    @State private var answers: [String: String] = [:]
    @State private var activeQuestionID: String?
    @State private var isGenerating = false
    @State private var briefing: BriefingResponse?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(questions) { question in
                        questionCard(question)
                    }

                    Button {
                        Task { await generateBriefing() }
                    } label: {
                        if isGenerating {
                            ProgressView().tint(Theme.navy)
                        } else {
                            Text("Generate Briefing")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.gold)
                    .foregroundStyle(Theme.navy)
                    .cornerRadius(12)
                    .disabled(isGenerating)

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red)
                    }

                    if let briefing {
                        briefingCard(briefing)
                    }
                }
                .padding()
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Aurora")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
        .task {
            _ = await speech.requestPermissions()
        }
    }

    private func questionCard(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.prompt)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            HStack {
                TextField("Answer", text: binding(for: question.id), axis: .vertical)
                    .foregroundStyle(Theme.cream)
                    .textFieldStyle(.plain)

                Button {
                    toggleRecording(for: question.id)
                } label: {
                    Image(systemName: speech.isRecording && activeQuestionID == question.id ? "mic.fill" : "mic")
                        .foregroundStyle(speech.isRecording && activeQuestionID == question.id ? Theme.red : Theme.gold)
                }
            }
            .padding()
            .background(Theme.navy2)
            .cornerRadius(10)
        }
    }

    private func briefingCard(_ briefing: BriefingResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(briefing.date)
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Spacer()
                Button {
                    speech.speak(briefing.briefing)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.gold)
                }
            }
            Text(briefing.briefing)
                .foregroundStyle(Theme.cream)
        }
        .padding()
        .background(Theme.navy2)
        .cornerRadius(10)
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { answers[id] ?? "" },
            set: { answers[id] = $0 }
        )
    }

    private func toggleRecording(for id: String) {
        if speech.isRecording, activeQuestionID == id {
            speech.stopRecording()
            answers[id] = speech.transcript
            activeQuestionID = nil
            return
        }

        activeQuestionID = id
        do {
            try speech.startRecording()
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
            activeQuestionID = nil
        }
    }

    private func generateBriefing() async {
        if speech.isRecording { speech.stopRecording() }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            briefing = try await APIService.shared.generateBriefing(answers: answers)
            if let briefing {
                speech.speak(briefing.briefing)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
