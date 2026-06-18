import SwiftUI

struct ProfileView: View {
    @State private var text = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView().tint(Theme.gold)
                    Spacer()
                } else {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Theme.cream)
                        .padding()
                        .background(Theme.navy2)
                        .cornerRadius(10)
                        .padding()

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
        .task { await load() }
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
}
