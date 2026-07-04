import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var todaysBriefing: BriefingResponse?
    @State private var isLoadingBriefing = true
    @State private var messages: [ChatMessage] = []
    @State private var draftText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var pendingAction: PendingAction?
    @State private var isConfirming = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoadingBriefing {
                    ProgressView().tint(Theme.gold)
                    Spacer()
                } else if todaysBriefing == nil {
                    Spacer()
                    Text("Generate today's briefing on the Today tab first — then come back here to ask Aurora about it.")
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                messageBubble(message)
                            }
                            if isSending {
                                ProgressView().tint(Theme.gold)
                            }
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(Theme.red)
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.immediately)
                    if let action = pendingAction {
                        confirmationBanner(action)
                    }
                    inputBar
                }
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Chat")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
        .task {
            await loadTodaysBriefing()
        }
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isRecording { draftText = newValue }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                Text(message.content).foregroundStyle(Theme.cream).padding().background(Theme.navy2).cornerRadius(10)
                Spacer()
            } else {
                Spacer()
                Text(message.content).foregroundStyle(Theme.navy).padding().background(Theme.gold).cornerRadius(10)
            }
        }
    }

    private func confirmationBanner(_ action: PendingAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add task:")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(action.params.text)
                .foregroundStyle(Theme.cream)
                .font(.subheadline)
            Text(Domain(rawValue: action.params.domain)?.label ?? action.params.domain)
                .font(.caption)
                .foregroundStyle(Theme.gold)
            HStack(spacing: 12) {
                Button {
                    Task { await confirmAction(action) }
                } label: {
                    Label("Confirm", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.navy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.gold)
                        .cornerRadius(8)
                }
                .disabled(isConfirming)

                Button("Cancel") {
                    pendingAction = nil
                }
                .foregroundStyle(Theme.muted)
                .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.navy2)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func confirmAction(_ action: PendingAction) async {
        guard action.type == "add_task" else { return }
        isConfirming = true
        pendingAction = nil
        defer { isConfirming = false }

        do {
            _ = try await APIService.shared.addTask(text: action.params.text, domain: action.params.domain)
            let domainLabel = Domain(rawValue: action.params.domain)?.label ?? action.params.domain
            let confirmation = "Done — added to your \(domainLabel) tasks."
            messages.append(ChatMessage(role: .assistant, content: confirmation))
            speech.speak(confirmation)
            try? await APIService.shared.saveChatHistory(date: todayDateString, messages: messages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var inputBar: some View {
        HStack {
            TextField("Ask Aurora…", text: $draftText, axis: .vertical)
                .foregroundStyle(Theme.cream)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Theme.navy2)
                .cornerRadius(10)

            Button {
                toggleRecording()
            } label: {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(speech.isRecording ? Theme.red : Theme.gold)
            }

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(Theme.gold)
            }
            .accessibilityLabel("Send message")
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding()
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        try? speech.startRecording()
    }

    private var todayDateString: String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(10))
    }

    private func loadTodaysBriefing() async {
        isLoadingBriefing = true
        defer { isLoadingBriefing = false }
        todaysBriefing = try? await APIService.shared.fetchBriefing(date: todayDateString)
        if todaysBriefing != nil {
            messages = (try? await APIService.shared.fetchChatHistory(date: todayDateString)) ?? []
        }
    }

    private func send() async {
        guard let briefing = todaysBriefing else { return }
        if speech.isRecording { speech.stopRecording() }

        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        pendingAction = nil
        messages.append(ChatMessage(role: .user, content: text))

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let chatReply = try await APIService.shared.sendChat(
                briefingDate: briefing.date,
                briefingText: briefing.briefing,
                messages: messages
            )
            messages.append(ChatMessage(role: .assistant, content: chatReply.reply))
            speech.speak(chatReply.reply)
            if let action = chatReply.pendingAction {
                pendingAction = action
            }
            try? await APIService.shared.saveChatHistory(date: todayDateString, messages: messages)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
