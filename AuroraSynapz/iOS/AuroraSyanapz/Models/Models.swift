import Foundation

struct AuthUser: Codable {
    let id: Int
    let name: String
    let email: String
    let role: String
}

struct LoginResponse: Codable {
    let token: String
    let user: AuthUser
}

struct Portfolio: Codable {
    let id: Int
    let userId: Int
    let totalValue: Double
    let cashBalance: Double
    let dayChange: Double
    let dayChangePct: Double
    let ytdReturn: Double
    let ytdReturnPct: Double
    let inceptionDate: String
    let updatedAt: String?
    var totalInvested: Double?
    var allTimeGain: Double?
    var allTimeGainPct: Double?

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id"
        case totalValue = "total_value"
        case cashBalance = "cash_balance"
        case dayChange = "day_change"
        case dayChangePct = "day_change_pct"
        case ytdReturn = "ytd_return"
        case ytdReturnPct = "ytd_return_pct"
        case inceptionDate = "inception_date"
        case updatedAt = "updated_at"
        case totalInvested = "total_invested"
        case allTimeGain = "all_time_gain"
        case allTimeGainPct = "all_time_gain_pct"
    }
}

struct Holding: Codable, Identifiable {
    let id: Int
    let userId: Int
    let symbol: String
    let name: String
    let assetClass: String
    let shares: Double
    let price: Double
    let avgCost: Double
    let dayChange: Double
    let dayChgPct: Double
    var marketValue: Double?
    var totalGain: Double?
    var totalGainPct: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, shares, price
        case userId = "user_id"
        case assetClass = "asset_class"
        case avgCost = "avg_cost"
        case dayChange = "day_change"
        case dayChgPct = "day_chg_pct"
        case marketValue = "market_value"
        case totalGain = "total_gain"
        case totalGainPct = "total_gain_pct"
    }
}

struct Transaction: Codable, Identifiable {
    let id: Int
    let type: String
    let symbol: String?
    let name: String?
    let shares: Double?
    let price: Double?
    let amount: Double
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, symbol, name, shares, price, amount, note
        case createdAt = "created_at"
    }
}

struct PerformancePoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let value: Double

    var dateValue: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: date) ?? Date()
    }
}

struct AllocationItem: Codable, Identifiable {
    var id: String { label }
    let label: String
    let value: Double
    let pct: Double
}

struct Document: Codable, Identifiable {
    let id: Int
    let title: String
    let type: String
    let period: String
    let sizeKb: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, type, period
        case sizeKb = "size_kb"
        case createdAt = "created_at"
    }
}

struct AdminStats: Codable {
    let totalAum: Double
    let clientCount: Int
    let contactCount: Int
    let totalDeposits: Double

    enum CodingKeys: String, CodingKey {
        case totalAum = "total_aum"
        case clientCount = "client_count"
        case contactCount = "contact_count"
        case totalDeposits = "total_deposits"
    }
}

struct AdminUser: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let createdAt: String
    let totalValue: Double?
    let dayChangePct: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case createdAt = "created_at"
        case totalValue = "total_value"
        case dayChangePct = "day_change_pct"
    }
}

struct Contact: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let service: String?
    let assets: String?
    let message: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, email, phone, service, assets, message
        case firstName = "first_name"
        case lastName = "last_name"
        case createdAt = "created_at"
    }

    var fullName: String { "\(firstName) \(lastName)" }
}
