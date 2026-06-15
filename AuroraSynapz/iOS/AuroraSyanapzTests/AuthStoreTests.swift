import XCTest
@testable import AuroraSyanapz

final class AuthStoreTests: XCTestCase {
    private let tokenKey = "aurora_token"
    private let userKey  = "aurora_user"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsLoggedOut() {
        let store = AuthStore()
        XCTAssertFalse(store.isLoggedIn)
        XCTAssertFalse(store.isAdmin)
        XCTAssertNil(store.token)
        XCTAssertNil(store.user)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - Persistence

    func testRestoresTokenFromUserDefaults() {
        UserDefaults.standard.set("saved-token", forKey: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        XCTAssertTrue(store.isLoggedIn)
        XCTAssertEqual(store.token, "saved-token")
    }

    func testRestoresUserFromUserDefaults() {
        UserDefaults.standard.set("saved-token", forKey: tokenKey)
        seedUser(name: "Test User", email: "test@example.com", role: "client")

        let store = AuthStore()
        XCTAssertEqual(store.user?.name, "Test User")
        XCTAssertEqual(store.user?.email, "test@example.com")
    }

    func testPersistenceAcrossMultipleInstances() {
        UserDefaults.standard.set("shared-token", forKey: tokenKey)
        seedUser(role: "client")

        let store1 = AuthStore()
        let store2 = AuthStore()
        XCTAssertEqual(store1.token, store2.token)
        XCTAssertEqual(store1.user?.id, store2.user?.id)
    }

    // MARK: - isLoggedIn / isAdmin

    func testIsLoggedInRequiresBothTokenAndUser() {
        UserDefaults.standard.set("token-only", forKey: tokenKey)
        // No user stored
        let store = AuthStore()
        XCTAssertFalse(store.isLoggedIn)
    }

    func testIsAdminTrueForAdminRole() {
        UserDefaults.standard.set("admin-token", forKey: tokenKey)
        seedUser(role: "admin")
        let store = AuthStore()
        XCTAssertTrue(store.isAdmin)
    }

    func testIsAdminFalseForClientRole() {
        UserDefaults.standard.set("client-token", forKey: tokenKey)
        seedUser(role: "client")
        let store = AuthStore()
        XCTAssertFalse(store.isAdmin)
    }

    // MARK: - logout

    func testLogoutClearsMemoryState() {
        UserDefaults.standard.set("logout-token", forKey: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        XCTAssertTrue(store.isLoggedIn)

        store.logout()
        XCTAssertFalse(store.isLoggedIn)
        XCTAssertNil(store.token)
        XCTAssertNil(store.user)
    }

    func testLogoutRemovesUserDefaultsEntries() {
        UserDefaults.standard.set("logout-token", forKey: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        store.logout()

        XCTAssertNil(UserDefaults.standard.string(forKey: tokenKey))
        XCTAssertNil(UserDefaults.standard.data(forKey: userKey))
    }

    func testLogoutThenNewInstanceIsLoggedOut() {
        UserDefaults.standard.set("gone-token", forKey: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        store.logout()

        let freshStore = AuthStore()
        XCTAssertFalse(freshStore.isLoggedIn)
    }

    // MARK: - Helpers

    private func seedUser(name: String = "Seed User", email: String = "seed@example.com", role: String) {
        let user = AuthUser(id: 99, name: name, email: email, role: role)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }
}
