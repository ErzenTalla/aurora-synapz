import SwiftUI

struct ProfileView: View {
    @StateObject private var notifications = NotificationService.shared
    @State private var text = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var googleStatus: GoogleStatus?
    @State private var isCheckingGoogle = false
    @FocusState private var isEditorFocused: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView().tint(Theme.gold)
                    Spacer()
                } else {
                    googleAccountSection

                    reminderSection

                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Theme.cream)
                        .padding()
                        .background(Theme.navy2)
                        .cornerRadius(10)
                        .padding()
                        .focused($isEditorFocused)
                        .toolbar {
                            ToolbarItem(placement: .keyboard) {
                                Button("Done") { isEditorFocused = false }
                                    .foregroundStyle(Theme.gold)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Theme.red).padding(.horizontal)
                    }
                    if let savedMessage {
                        Text(savedMessage).foregroundStyle(Theme.gold).padding(.horizontal)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Theme.navy)
                        } else {
                            Text("Save")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.gold)
                    .foregroundStyle(Theme.navy)
                    .cornerRadius(12)
                    .disabled(isSaving)
                    .padding()
                }
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Profile")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
        .task {
            await load()
            await checkGoogleStatus()
        }
        .onAppear {
            Task { await checkGoogleStatus() }
        }
    }

    private var googleAccountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Google Account").foregroundStyle(Theme.cream).fontWeight(.medium)

            if isCheckingGoogle {
                ProgressView().tint(Theme.gold)
            } else if let googleStatus, googleStatus.connected {
                Text("Connected as \(googleStatus.email ?? "unknown")")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button("Disconnect") {
                    Task { await disconnectGoogle() }
                }
                .foregroundStyle(Theme.red)
            } else {
                Text("Not connected — Aurora can't see your calendar or email yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Button("Connect Google Account") {
                    openURL(APIService.shared.googleAuthURL)
                }
                .foregroundStyle(Theme.gold)
            }
        }
        .padding()
        .background(Theme.navy2)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { notifications.isEnabled },
                set: { newValue in Task { await notifications.setEnabled(newValue) } }
            )) {
                Text("Daily Reminder").foregroundStyle(Theme.cream)
            }
            .tint(Theme.gold)

            if notifications.isEnabled {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { notifications.time },
                        set: { notifications.updateTime($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .foregroundStyle(Theme.cream)
            }
        }
        .padding()
        .background(Theme.navy2)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            text = try await APIService.shared.fetchProfile().profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        savedMessage = nil
        defer { isSaving = false }
        do {
            try await APIService.shared.saveProfile(text)
            savedMessage = "Saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkGoogleStatus() async {
        isCheckingGoogle = true
        defer { isCheckingGoogle = false }
        googleStatus = try? await APIService.shared.checkGoogleStatus()
    }

    private func disconnectGoogle() async {
        try? await APIService.shared.disconnectGoogle()
        await checkGoogleStatus()
    }
}
