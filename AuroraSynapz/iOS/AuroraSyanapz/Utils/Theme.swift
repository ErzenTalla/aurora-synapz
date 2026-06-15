import SwiftUI

enum Theme {
    static let navy    = Color(hex: "#0D1B2A")
    static let navy2   = Color(hex: "#091420")
    static let navy3   = Color(hex: "#060F18")
    static let navyM   = Color(hex: "#152E45")
    static let gold    = Color(hex: "#C9A84C")
    static let gold2   = Color(hex: "#E2C870")
    static let cream   = Color(hex: "#F5F0E8")
    static let muted   = Color(hex: "#F5F0E8").opacity(0.5)
    static let muted2  = Color(hex: "#F5F0E8").opacity(0.7)
    static let green   = Color(hex: "#4CAF7D")
    static let red     = Color(hex: "#E05252")
    static let blue    = Color(hex: "#8AB4F8")
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

extension Double {
    func asCurrency() -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "$0"
    }

    func asCurrencyPrecise() -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    func asPct() -> String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    func color() -> Color { self >= 0 ? Theme.green : Theme.red }
}
