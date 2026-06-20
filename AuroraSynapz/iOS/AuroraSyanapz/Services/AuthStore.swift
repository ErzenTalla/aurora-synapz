import Foundation
import Combine

class AuthStore: ObservableObject {
    @Published var token: String?
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Face ID app-lock. isUnlocked starts false whenever locking is enabled and
    // there's a session to protect, so launching the app always requires a
    // fresh unlock — LockView handles the actual biometric prompt.
    @Published var isUnlocked: Bool = true
    @Published var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: faceIDKey) }
    }

    private let tokenKey  = "aurora_token"
    private let userKey   = "aurora_user"
    private let faceIDKey = "aurora_faceid_enabled"
    private var unauthorizedObserver: NSObjectProtocol?

    init() {
        token = KeychainHelper.loadString(key: tokenKey)
        if let data = KeychainHelper.load(key: userKey) {
            user = try? JSONDecoder().decode(AuthUser.self, from: data)
        }
        let faceID = UserDefaults.standard.bool(forKey: faceIDKey)
        faceIDEnabled = faceID
        isUnlocked = !(faceID && token != nil && user != nil)

        // A 401 from any API call means the session is no longer valid server-side —
        // bounce back to LoginView instead of leaving a dead error on screen.
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .auroraUnauthorized, object: nil, queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }

    deinit {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
        }
    }

    var isLoggedIn: Bool { token != nil && user != nil }
    var isAdmin: Bool { user?.role == "admin" }

    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let res = try await APIService.shared.login(email: email, password: password)
            await MainActor.run {
                self.token = res.token
                self.user  = res.user
                KeychainHelper.saveString(res.token, key: tokenKey)
                if let data = try? JSONEncoder().encode(res.user) {
                    KeychainHelper.save(data, key: userKey)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription; isLoading = false }
        }
    }

    func logout() {
        token = nil
        user  = nil
        isUnlocked = true
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: userKey)
    }

    // Re-lock when the app leaves the foreground, if Face ID lock is enabled.
    func lockIfNeeded() {
        if faceIDEnabled && isLoggedIn { isUnlocked = false }
    }
}
