import SwiftUI

enum Theme {
    static let navy    = Color(hex: "#0D1B2A")
    static let navy2   = Color(hex: "#091420")
    static let gold    = Color(hex: "#C9A84C")
    static let cream   = Color(hex: "#F5F0E8")
    static let muted   = Color(hex: "#F5F0E8").opacity(0.5)
    static let red     = Color(hex: "#E05252")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
