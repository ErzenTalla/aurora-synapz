import SwiftUI

struct DocumentsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var documents: [Document] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedDoc: Document?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = error {
                    ErrorRetryView(message: err) { Task { await load() } }
                } else if documents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.muted)
                        Text("No documents available.")
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    List(documents) { doc in
                        Button { selectedDoc = doc } label: {
                            DocumentRow(doc: doc)
                        }
                        .listRowBackground(Theme.navy)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedDoc) { doc in
                DocumentDetailSheet(doc: doc)
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        isLoading = true
        error = nil
        do {
            documents = try await APIService.shared.fetchDocuments(token: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct DocumentRow: View {
    let doc: Document

    var typeColor: Color {
        switch doc.type {
        case "Statement": return Theme.blue
        case "Tax":       return Theme.red
        case "Report":    return Theme.green
        default:          return Theme.gold
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.gold)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 5) {
                Text(doc.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(doc.type.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(typeColor.opacity(0.12))
                        .foregroundStyle(typeColor)
                    Text(doc.period)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    Text("\(doc.sizeKb) KB")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 8)
    }
}

struct DocumentDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let doc: Document

    var typeColor: Color {
        switch doc.type {
        case "Statement": return Theme.blue
        case "Tax":       return Theme.red
        case "Report":    return Theme.green
        default:          return Theme.gold
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Document icon
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Theme.gold)
                            Text(doc.title)
                                .font(.custom("Georgia", size: 20))
                                .foregroundStyle(Theme.cream)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        // Metadata
                        VStack(spacing: 0) {
                            MetaRow(label: "Type", value: doc.type, valueColor: typeColor)
                            Divider().background(Theme.gold.opacity(0.08))
                            MetaRow(label: "Period", value: doc.period)
                            Divider().background(Theme.gold.opacity(0.08))
                            MetaRow(label: "Size", value: "\(doc.sizeKb) KB")
                            Divider().background(Theme.gold.opacity(0.08))
                            MetaRow(label: "Added", value: String(doc.createdAt.prefix(10)))
                        }
                        .background(Theme.navy)
                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal)

                        // Download notice
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.gold.opacity(0.5))
                            Text("To download this document, contact your advisor at")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                            Text("support@aurorasyanapz.com")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Theme.navy)
                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle(doc.type)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
    }
}

