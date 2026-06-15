import Foundation
import Combine

class AuthStore: ObservableObject {
    @Published var token: String?
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenKey = "aurora_token"
    private let userKey  = "aurora_user"

    init() {
        token = UserDefaults.standard.string(forKey: tokenKey)
        if let data = UserDefaults.standard.data(forKey: userKey) {
            user = try? JSONDecoder().decode(AuthUser.self, from: data)
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
                UserDefaults.standard.set(res.token, forKey: tokenKey)
                if let data = try? JSONEncoder().encode(res.user) {
                    UserDefaults.standard.set(data, forKey: userKey)
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
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }
}
