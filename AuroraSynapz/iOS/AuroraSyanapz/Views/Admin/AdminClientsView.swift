import SwiftUI

struct AdminClientsView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var showCreate = false
    @State private var selectedUser: AdminUser?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else {
                    List {
                        ForEach(users) { u in
                            Button { selectedUser = u } label: {
                                AdminUserRow(user: u)
                            }
                            .listRowBackground(Theme.navy)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete { indices in
                            Task { await deleteUsers(at: indices) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.gold)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(users.count) accounts")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateClientSheet { await loadUsers() }
            }
            .sheet(item: $selectedUser) { u in
                ClientDetailSheet(user: u)
            }
        }
        .task { await loadUsers() }
    }

    func loadUsers() async {
        guard let token = auth.token else { return }
        if let u = try? await APIService.shared.fetchAdminUsers(token: token) { users = u }
        isLoading = false
    }

    func deleteUsers(at indices: IndexSet) async {
        guard let token = auth.token else { return }
        for i in indices {
            let u = users[i]
            guard u.role != "admin" else { continue }
            try? await APIService.shared.deleteUser(id: u.id, token: token)
        }
        await loadUsers()
    }
}

struct CreateClientSheet: View {
    @EnvironmentObject var auth: AuthStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isCreating = false
    let onCreated: () async -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let err = error {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.red.opacity(0.1))
                                .overlay(Rectangle().stroke(Theme.red.opacity(0.3), lineWidth: 1))
                        }

                        FormField(label: "Full Name", text: $name, placeholder: "Jane Smith")
                        FormField(label: "Email Address", text: $email, placeholder: "jane@example.com", keyboard: .emailAddress)
                        FormField(label: "Temporary Password", text: $password, placeholder: "Min. 8 characters")

                        Button {
                            Task { await createClient() }
                        } label: {
                            HStack {
                                if isCreating { ProgressView().tint(Theme.navy) }
                                else { Text("CREATE ACCOUNT").font(.system(size: 12, weight: .bold)).tracking(2) }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.gold)
                            .foregroundStyle(Theme.navy)
                        }
                        .disabled(isCreating || name.isEmpty || email.isEmpty || password.isEmpty)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.muted)
                }
            }
        }
    }

    func createClient() async {
        error = nil
        guard let token = auth.token else { return }
        isCreating = true
        do {
            _ = try await APIService.shared.createUser(name: name, email: email, password: password, token: token)
            await onCreated()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}

struct ClientDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let user: AdminUser

    var initials: String {
        user.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar + name
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(user.role == "admin" ? Theme.gold.opacity(0.2) : Theme.blue.opacity(0.15))
                                    .frame(width: 72, height: 72)
                                Text(initials)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(user.role == "admin" ? Theme.gold : Theme.blue)
                            }
                            Text(user.name)
                                .font(.custom("Georgia", size: 22))
                                .foregroundStyle(Theme.cream)
                            Text(user.role.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2)
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(user.role == "admin" ? Theme.gold.opacity(0.12) : Theme.blue.opacity(0.1))
                                .foregroundStyle(user.role == "admin" ? Theme.gold : Theme.blue)
                        }
                        .padding(.top, 12)

                        // Account info
                        VStack(spacing: 0) {
                            MetaRow(label: "Email", value: user.email)
                            Divider().background(Theme.gold.opacity(0.08))
                            MetaRow(label: "Account ID", value: "#\(user.id)")
                            Divider().background(Theme.gold.opacity(0.08))
                            MetaRow(label: "Member Since", value: String(user.createdAt.prefix(10)))
                        }
                        .background(Theme.navy)
                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal)

                        // Portfolio summary (from list data)
                        if let value = user.totalValue {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatCard(label: "Portfolio Value", value: value.asCurrency(), sub: "As of last sync", subColor: Theme.muted)
                                if let dayPct = user.dayChangePct {
                                    StatCard(label: "Today", value: dayPct.asPct(), sub: "Day change", subColor: dayPct.color())
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Note about full detail
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Theme.gold.opacity(0.7))
                            Text("Full portfolio breakdown is available in the web dashboard.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.navy)
                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal)

                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationTitle(user.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
    }
}


struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.muted)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .autocapitalization(keyboard == .emailAddress ? .none : .words)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.cream)
                .padding(14)
                .background(Theme.navyM.opacity(0.5))
                .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
        }
    }
}
