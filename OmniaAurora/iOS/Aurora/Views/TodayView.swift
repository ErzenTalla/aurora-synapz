import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var started = false
    @State private var answers: [String: String] = [:]
    @State private var draftText = ""
    @State private var currentIndex = 0
    @State private var isGenerating = false
    @State private var briefing: BriefingResponse?
    @State private var errorMessage: String?

    private var currentQuestion: Question? {
        currentIndex < questions.count ? questions[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if briefing == nil {
                        if !started {
                            startCard
                        } else if let question = currentQuestion {
                            conversationCard(question)
                        } else if isGenerating {
                            ProgressView("Generating your briefing…").tint(Theme.gold)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red)
                    }

                    if let briefing {
                        briefingCard(briefing)
                        Button("Start Over") { reset() }
                            .foregroundStyle(Theme.gold)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Today")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
        .task {
            _ = await speech.requestPermissions()
        }
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isRecording { draftText = newValue }
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ready to talk through today?")
                .font(.title3)
                .foregroundStyle(Theme.cream)
            Text("Aurora will ask you six questions out loud — answer by voice or type if you'd rather.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Button("Start") { begin() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.gold)
                .foregroundStyle(Theme.navy)
                .cornerRadius(12)
        }
    }

    private func conversationCard(_ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question \(currentIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(question.prompt)
                .font(.headline)
                .foregroundStyle(Theme.cream)

            HStack {
                TextField("Answer", text: $draftText, axis: .vertical)
                    .foregroundStyle(Theme.cream)
                    .textFieldStyle(.plain)

                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                        .foregroundStyle(speech.isRecording ? Theme.red : Theme.gold)
                }
                .disabled(speech.isSpeaking)
            }
            .padding()
            .background(Theme.navy2)
            .cornerRadius(10)

            Button(currentIndex == questions.count - 1 ? "Generate Briefing" : "Next") {
                confirmAnswer()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.gold)
            .foregroundStyle(Theme.navy)
            .cornerRadius(12)
        }
        .padding()
        .background(Theme.navy2.opacity(0.4))
        .cornerRadius(12)
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

    private func begin() {
        started = true
        currentIndex = 0
        answers = [:]
        askCurrentQuestion()
    }

    private func reset() {
        started = false
        currentIndex = 0
        answers = [:]
        draftText = ""
        briefing = nil
        errorMessage = nil
    }

    private func askCurrentQuestion() {
        guard let question = currentQuestion else {
            Task { await generateBriefing() }
            return
        }
        draftText = answers[question.id] ?? ""
        speech.speak(question.prompt) {
            do {
                try speech.startRecording()
            } catch {
                errorMessage = "Couldn't start listening: \(error.localizedDescription)"
            }
        }
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        do {
            try speech.startRecording()
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    private func confirmAnswer() {
        if speech.isRecording { speech.stopRecording() }
        guard let question = currentQuestion else { return }
        answers[question.id] = draftText
        currentIndex += 1
        askCurrentQuestion()
    }

    private func generateBriefing() async {
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
