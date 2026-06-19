import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var section = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    Text("Tasks").tag(0)
                    Text("Notes").tag(1)
                    Text("Knowledge").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                switch section {
                case 0: TasksSection()
                case 1: NotesSection()
                default: KnowledgeSection()
                }
            }
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Workspace")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
    }
}

private struct TasksSection: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var tasks: [TaskItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Theme.gold)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.red)
            } else if tasks.isEmpty {
                Text("No tasks yet.").foregroundStyle(Theme.muted)
            } else {
                List {
                    ForEach(tasks) { task in
                        Button {
                            Task { await toggle(task) }
                        } label: {
                            HStack {
                                Image(systemName: task.status == "done" ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.status == "done" ? Theme.gold : Theme.muted)
                                VStack(alignment: .leading) {
                                    Text(task.text).foregroundStyle(Theme.cream)
                                        .strikethrough(task.status == "done")
                                    Text(Domain(rawValue: task.domain ?? "general")?.label ?? "General")
                                        .font(.caption).foregroundStyle(Theme.muted)
                                }
                            }
                        }
                        .listRowBackground(Theme.navy2)
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Open Add Sheet")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddItemSheet(speech: speech, includeDomain: true) { text, domain in
                await add(text: text, domain: domain)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { tasks = try await APIService.shared.listTasks() } catch { errorMessage = error.localizedDescription }
    }

    private func add(text: String, domain: String) async {
        do {
            let task = try await APIService.shared.addTask(text: text, domain: domain)
            tasks.insert(task, at: 0)
        } catch { errorMessage = error.localizedDescription }
    }

    private func toggle(_ task: TaskItem) async {
        let newStatus = task.status == "done" ? "open" : "done"
        do {
            let updated = try await APIService.shared.setTaskStatus(id: task.id, status: newStatus)
            if let idx = tasks.firstIndex(where: { $0.id == task.id }) { tasks[idx] = updated }
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(at offsets: IndexSet) async {
        for index in offsets {
            let task = tasks[index]
            do { try await APIService.shared.deleteTask(id: task.id) } catch { errorMessage = error.localizedDescription }
        }
        tasks.remove(atOffsets: offsets)
    }
}

private struct NotesSection: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var notes: [NoteItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Theme.gold)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.red)
            } else if notes.isEmpty {
                Text("No notes yet.").foregroundStyle(Theme.muted)
            } else {
                List {
                    ForEach(notes) { note in
                        VStack(alignment: .leading) {
                            Text(note.text).foregroundStyle(Theme.cream)
                            Text(Domain(rawValue: note.domain ?? "general")?.label ?? "General")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        .listRowBackground(Theme.navy2)
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Open Add Sheet")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddItemSheet(speech: speech, includeDomain: true) { text, domain in
                await add(text: text, domain: domain)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { notes = try await APIService.shared.listNotes() } catch { errorMessage = error.localizedDescription }
    }

    private func add(text: String, domain: String) async {
        do {
            let note = try await APIService.shared.addNote(text: text, domain: domain)
            notes.insert(note, at: 0)
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(at offsets: IndexSet) async {
        for index in offsets {
            let note = notes[index]
            do { try await APIService.shared.deleteNote(id: note.id) } catch { errorMessage = error.localizedDescription }
        }
        notes.remove(atOffsets: offsets)
    }
}

private struct KnowledgeSection: View {
    @EnvironmentObject private var speech: SpeechService
    @State private var facts: [KnowledgeFact] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingAdd = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(Theme.gold)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Theme.red)
            } else if facts.isEmpty {
                Text("Nothing tracked yet.").foregroundStyle(Theme.muted)
            } else {
                List {
                    ForEach(facts) { fact in
                        Text(fact.text).foregroundStyle(Theme.cream).listRowBackground(Theme.navy2)
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Open Add Sheet")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddItemSheet(speech: speech, includeDomain: false) { text, _ in
                await add(text: text)
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { facts = try await APIService.shared.listKnowledge() } catch { errorMessage = error.localizedDescription }
    }

    private func add(text: String) async {
        do {
            let fact = try await APIService.shared.addKnowledge(text: text)
            facts.insert(fact, at: 0)
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(at offsets: IndexSet) async {
        for index in offsets {
            let fact = facts[index]
            do { try await APIService.shared.deleteKnowledge(id: fact.id) } catch { errorMessage = error.localizedDescription }
        }
        facts.remove(atOffsets: offsets)
    }
}

private struct AddItemSheet: View {
    @ObservedObject var speech: SpeechService
    let includeDomain: Bool
    let onAdd: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var domain: Domain = .general
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("What's on your mind?", text: $text, axis: .vertical)
                        .foregroundStyle(Theme.cream)
                        .textFieldStyle(.plain)
                    Button {
                        toggleRecording()
                    } label: {
                        Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                            .foregroundStyle(speech.isRecording ? Theme.red : Theme.gold)
                    }
                }
                .padding()
                .background(Theme.navy2)
                .cornerRadius(10)

                if includeDomain {
                    Picker("Domain", selection: $domain) {
                        ForEach(Domain.allCases) { d in Text(d.label).tag(d) }
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    Task {
                        isSaving = true
                        await onAdd(text, domain.rawValue)
                        isSaving = false
                        dismiss()
                    }
                } label: {
                    if isSaving { ProgressView().tint(Theme.navy) } else { Text("Add") }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.gold)
                .foregroundStyle(Theme.navy)
                .cornerRadius(12)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                Spacer()
            }
            .padding()
            .background(Theme.navy.ignoresSafeArea())
            .navigationTitle("Add")
            .toolbarBackground(Theme.navy, for: .navigationBar)
        }
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isRecording { text = newValue }
        }
    }

    private func toggleRecording() {
        if speech.isRecording {
            speech.stopRecording()
            return
        }
        try? speech.startRecording()
    }
}
