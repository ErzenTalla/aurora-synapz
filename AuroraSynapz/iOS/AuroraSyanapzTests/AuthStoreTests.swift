import XCTest
@testable import AuroraSyanapz

final class AuthStoreTests: XCTestCase {
    private let tokenKey = "aurora_token"
    private let userKey  = "aurora_user"

    override func setUp() {
        super.setUp()
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: userKey)
    }

    override func tearDown() {
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: userKey)
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

    func testRestoresTokenFromKeychain() {
        KeychainHelper.saveString("saved-token", key: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        XCTAssertTrue(store.isLoggedIn)
        XCTAssertEqual(store.token, "saved-token")
    }

    func testRestoresUserFromKeychain() {
        KeychainHelper.saveString("saved-token", key: tokenKey)
        seedUser(name: "Test User", email: "test@example.com", role: "client")

        let store = AuthStore()
        XCTAssertEqual(store.user?.name, "Test User")
        XCTAssertEqual(store.user?.email, "test@example.com")
    }

    func testPersistenceAcrossMultipleInstances() {
        KeychainHelper.saveString("shared-token", key: tokenKey)
        seedUser(role: "client")

        let store1 = AuthStore()
        let store2 = AuthStore()
        XCTAssertEqual(store1.token, store2.token)
        XCTAssertEqual(store1.user?.id, store2.user?.id)
    }

    // MARK: - isLoggedIn / isAdmin

    func testIsLoggedInRequiresBothTokenAndUser() {
        KeychainHelper.saveString("token-only", key: tokenKey)
        // No user stored
        let store = AuthStore()
        XCTAssertFalse(store.isLoggedIn)
    }

    func testIsAdminTrueForAdminRole() {
        KeychainHelper.saveString("admin-token", key: tokenKey)
        seedUser(role: "admin")
        let store = AuthStore()
        XCTAssertTrue(store.isAdmin)
    }

    func testIsAdminFalseForClientRole() {
        KeychainHelper.saveString("client-token", key: tokenKey)
        seedUser(role: "client")
        let store = AuthStore()
        XCTAssertFalse(store.isAdmin)
    }

    // MARK: - logout

    func testLogoutClearsMemoryState() {
        KeychainHelper.saveString("logout-token", key: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        XCTAssertTrue(store.isLoggedIn)

        store.logout()
        XCTAssertFalse(store.isLoggedIn)
        XCTAssertNil(store.token)
        XCTAssertNil(store.user)
    }

    func testLogoutRemovesKeychainEntries() {
        KeychainHelper.saveString("logout-token", key: tokenKey)
        seedUser(role: "client")

        let store = AuthStore()
        store.logout()

        XCTAssertNil(KeychainHelper.loadString(key: tokenKey))
        XCTAssertNil(KeychainHelper.load(key: userKey))
    }

    func testLogoutThenNewInstanceIsLoggedOut() {
        KeychainHelper.saveString("gone-token", key: tokenKey)
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
            KeychainHelper.save(data, key: userKey)
        }
    }
}
