import SwiftUI
import UniformTypeIdentifiers

struct AdminDocumentsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var documents: [Document] = []
    @State private var isLoading = true
    @State private var showUpload = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.muted)
                        Text("No documents yet.")
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    List {
                        ForEach(documents) { doc in
                            AdminDocumentRow(doc: doc)
                                .listRowBackground(Theme.navy)
                        }
                        .onDelete { indices in
                            Task { await delete(at: indices) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showUpload = true } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.gold)
                    }
                }
            }
            .sheet(isPresented: $showUpload) {
                UploadDocumentSheet { await load() }
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        if let d = try? await APIService.shared.fetchAdminDocuments(token: token) { documents = d }
        isLoading = false
    }

    func delete(at indices: IndexSet) async {
        guard let token = auth.token else { return }
        for i in indices {
            try? await APIService.shared.deleteDocument(id: documents[i].id, token: token)
        }
        await load()
    }
}

struct AdminDocumentRow: View {
    let doc: Document

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.gold)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cream)
                Text("\(doc.name ?? "—") · \(doc.type) · \(doc.period)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text("\(doc.sizeKb) KB").font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 6)
    }
}

struct UploadDocumentSheet: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) var dismiss
    let onUploaded: () async -> Void

    @State private var users: [AdminUser] = []
    @State private var selectedUserId: Int?
    @State private var title = ""
    @State private var docType = "Statement"
    @State private var period = ""
    @State private var fileData: Data?
    @State private var pickedFileName: String?
    @State private var pickedMimeType = "application/pdf"
    @State private var showFileImporter = false
    @State private var error: String?
    @State private var isUploading = false

    let types = ["Statement", "Tax Form", "Report", "Agreement", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let error {
                            Text(error).font(.system(size: 12)).foregroundStyle(Theme.red)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CLIENT").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Theme.muted)
                            Picker("Client", selection: $selectedUserId) {
                                Text("Select a client").tag(Int?.none)
                                ForEach(users.filter { $0.role == "client" }) { u in
                                    Text(u.name).tag(Optional(u.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.gold)
                        }

                        FormField(label: "Title", text: $title, placeholder: "Q2 2026 Statement")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("TYPE").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(Theme.muted)
                            Picker("Type", selection: $docType) {
                                ForEach(types, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.gold)
                        }

                        FormField(label: "Period", text: $period, placeholder: "Q2 2026")

                        Button {
                            showFileImporter = true
                        } label: {
                            HStack {
                                Image(systemName: fileData == nil ? "doc.badge.plus" : "checkmark.circle.fill")
                                Text(pickedFileName ?? "Select PDF or photo")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(fileData == nil ? Theme.muted : Theme.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.navyM.opacity(0.5))
                            .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                        }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .png, .jpeg]) { result in
                            guard case .success(let url) = result else { return }
                            let accessed = url.startAccessingSecurityScopedResource()
                            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                            guard let data = try? Data(contentsOf: url) else { return }
                            fileData = data
                            pickedFileName = url.lastPathComponent
                            switch url.pathExtension.lowercased() {
                            case "png":  pickedMimeType = "image/png"
                            case "jpg", "jpeg": pickedMimeType = "image/jpeg"
                            default: pickedMimeType = "application/pdf"
                            }
                        }

                        Button {
                            Task { await upload() }
                        } label: {
                            HStack {
                                if isUploading { ProgressView().tint(Theme.navy) }
                                else { Text("UPLOAD").font(.system(size: 12, weight: .bold)).tracking(2) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.gold)
                            .foregroundStyle(Theme.navy)
                        }
                        .disabled(isUploading || selectedUserId == nil || title.isEmpty || period.isEmpty || fileData == nil)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.muted)
                }
            }
        }
        .task {
            guard let token = auth.token else { return }
            users = (try? await APIService.shared.fetchAdminUsers(token: token)) ?? []
        }
    }

    func upload() async {
        error = nil
        guard let userId = selectedUserId, let fileData else { return }
        guard let token = auth.token else { return }
        isUploading = true
        do {
            _ = try await APIService.shared.uploadDocument(
                userId: userId, title: title, type: docType, period: period,
                fileData: fileData, fileName: pickedFileName ?? "\(title).pdf", mimeType: pickedMimeType,
                token: token
            )
            await onUploaded()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isUploading = false
    }
}
