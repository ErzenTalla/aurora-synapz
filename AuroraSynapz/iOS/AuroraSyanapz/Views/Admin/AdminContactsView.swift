import SwiftUI

struct AdminContactsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var contacts: [Contact] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.muted)
                        Text("No contact submissions yet.")
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    List(contacts) { c in
                        ContactRow(contact: c)
                            .listRowBackground(Theme.navy)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(contacts.count)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        if let c = try? await APIService.shared.fetchAdminContacts(token: token) { contacts = c }
        isLoading = false
    }
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(contact.fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                    Text(contact.email)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(String(contact.createdAt.prefix(10)))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 8) {
                if let service = contact.service {
                    Tag(text: service, color: Theme.gold)
                }
                if let assets = contact.assets {
                    Tag(text: assets, color: Theme.blue)
                }
                if let phone = contact.phone {
                    Tag(text: phone, color: Theme.muted2)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
    }
}
