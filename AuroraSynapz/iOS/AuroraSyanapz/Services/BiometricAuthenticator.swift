import LocalAuthentication

enum BiometricAuthenticator {
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your Aurora Synapz portfolio"
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
