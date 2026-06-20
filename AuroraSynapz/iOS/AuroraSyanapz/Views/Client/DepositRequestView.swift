import SwiftUI
import PhotosUI

struct DepositRequestView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var requests: [DepositRequest] = []
    @State private var amountText = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy3.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let err = loadError {
                    ErrorRetryView(message: err) { Task { await load() } }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("New Deposit Request")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)

                                if let error {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.red)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("AMOUNT YOU'RE SENDING (USD)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Theme.muted)
                                    TextField("e.g. 200", text: $amountText)
                                        .keyboardType(.decimalPad)
                                        .foregroundStyle(Theme.cream)
                                        .padding(12)
                                        .background(Theme.navyM.opacity(0.5))
                                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("PROOF OF PAYMENT (OPTIONAL)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Theme.muted)

                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        HStack {
                                            Image(systemName: selectedImageData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                                            Text(selectedImageData == nil ? "Attach photo of receipt" : "Photo attached")
                                        }
                                        .font(.system(size: 13))
                                        .foregroundStyle(selectedImageData == nil ? Theme.muted : Theme.green)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Theme.navyM.opacity(0.5))
                                        .overlay(Rectangle().stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                                    }
                                    .onChange(of: selectedItem) { newItem in
                                        Task {
                                            if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                                                selectedImageData = data
                                            }
                                        }
                                    }
                                }

                                Text("Wire your funds to AlpineTech's bank account, then submit this request. Your advisor will confirm receipt and credit your account — this may take a few business days.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted2)
                                    .padding(12)
                                    .background(Theme.gold.opacity(0.06))
                                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.12), lineWidth: 1))

                                Button {
                                    Task { await submit() }
                                } label: {
                                    HStack {
                                        if isSubmitting { ProgressView().tint(Theme.navy) }
                                        else { Text("SUBMIT DEPOSIT REQUEST").font(.system(size: 11, weight: .bold)).tracking(2) }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(Theme.gold)
                                    .foregroundStyle(Theme.navy)
                                }
                                .disabled(isSubmitting)
                            }
                            .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Deposit Request History")
                                    .font(.custom("Georgia", size: 18))
                                    .foregroundStyle(Theme.cream)
                                    .padding(.horizontal)

                                if requests.isEmpty {
                                    Text("No deposit requests yet.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.muted)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(requests) { r in
                                            DepositRequestRow(r: r)
                                            if r.id != requests.last?.id {
                                                Divider().background(Theme.gold.opacity(0.08))
                                            }
                                        }
                                    }
                                    .background(Theme.navy)
                                    .overlay(Rectangle().stroke(Theme.gold.opacity(0.1), lineWidth: 1))
                                    .padding(.horizontal)
                                }
                            }

                            Spacer(minLength: 30)
                        }
                        .padding(.top, 12)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Wire Deposit")
            .navigationBarTitleDisplayMode(.large)
        }
        .task { await load() }
    }

    func load() async {
        guard let token = auth.token else { return }
        isLoading = true
        loadError = nil
        do {
            requests = try await APIService.shared.fetchDepositRequests(token: token)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func submit() async {
        error = nil
        guard let amount = Double(amountText), amount > 0 else {
            error = "Enter a valid amount"
            return
        }
        guard let token = auth.token else { return }
        isSubmitting = true
        do {
            _ = try await APIService.shared.submitDepositRequest(
                amount: amount,
                fileData: selectedImageData,
                fileName: "proof.jpg",
                mimeType: "image/jpeg",
                token: token
            )
            amountText = ""
            selectedItem = nil
            selectedImageData = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}

struct DepositRequestRow: View {
    let r: DepositRequest

    var statusColor: Color {
        switch r.status {
        case "pending":  return Theme.gold
        case "received": return Theme.green
        case "rejected": return Theme.red
        default:         return Theme.muted
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(r.amount.asCurrency())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                Text(String(r.createdAt.prefix(10)))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(r.status.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(statusColor.opacity(0.12))
                .foregroundStyle(statusColor)
        }
        .padding(14)
    }
}
