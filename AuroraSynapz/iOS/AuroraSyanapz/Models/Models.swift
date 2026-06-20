import Foundation

// Postgres NUMERIC columns are serialized as JSON strings by the `pg` driver
// unless the backend explicitly parseFloat's them before responding — decode
// either representation so every NUMERIC-backed field survives real responses,
// not just the hand-written (unquoted-number) JSON used in unit tests.
extension KeyedDecodingContainer {
    func lossyDouble(_ key: K) throws -> Double {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key), let d = Double(s) { return d }
        return 0
    }

    func lossyDoubleIfPresent(_ key: K) -> Double? {
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: key), let d = Double(s) { return d }
        return nil
    }
}

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

struct Portfolio: Decodable {
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
    let unitsOwned: Double?
    let feeRate: Double?
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
        case unitsOwned = "units_owned"
        case feeRate = "fee_rate"
        case totalInvested = "total_invested"
        case allTimeGain = "all_time_gain"
        case allTimeGainPct = "all_time_gain_pct"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        totalValue = try c.lossyDouble(.totalValue)
        cashBalance = try c.lossyDouble(.cashBalance)
        dayChange = try c.lossyDouble(.dayChange)
        dayChangePct = try c.lossyDouble(.dayChangePct)
        ytdReturn = try c.lossyDouble(.ytdReturn)
        ytdReturnPct = try c.lossyDouble(.ytdReturnPct)
        inceptionDate = try c.decode(String.self, forKey: .inceptionDate)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        unitsOwned = c.lossyDoubleIfPresent(.unitsOwned)
        feeRate = c.lossyDoubleIfPresent(.feeRate)
        totalInvested = c.lossyDoubleIfPresent(.totalInvested)
        allTimeGain = c.lossyDoubleIfPresent(.allTimeGain)
        allTimeGainPct = c.lossyDoubleIfPresent(.allTimeGainPct)
    }
}

// The pooled fund — single row representing the whole Alpaca account.
struct Fund: Decodable {
    let totalValue: Double
    let totalUnits: Double
    let unitPrice: Double

    enum CodingKeys: String, CodingKey {
        case totalValue = "total_value"
        case totalUnits = "total_units"
        case unitPrice = "unit_price"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalValue = try c.lossyDouble(.totalValue)
        totalUnits = try c.lossyDouble(.totalUnits)
        unitPrice = try c.lossyDouble(.unitPrice)
    }
}

struct Holding: Decodable, Identifiable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        symbol = try c.decode(String.self, forKey: .symbol)
        name = try c.decode(String.self, forKey: .name)
        assetClass = try c.decode(String.self, forKey: .assetClass)
        shares = try c.lossyDouble(.shares)
        price = try c.lossyDouble(.price)
        avgCost = try c.lossyDouble(.avgCost)
        dayChange = try c.lossyDouble(.dayChange)
        dayChgPct = try c.lossyDouble(.dayChgPct)
        marketValue = c.lossyDoubleIfPresent(.marketValue)
        totalGain = c.lossyDoubleIfPresent(.totalGain)
        totalGainPct = c.lossyDoubleIfPresent(.totalGainPct)
    }
}

struct Transaction: Decodable, Identifiable {
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        type = try c.decode(String.self, forKey: .type)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        shares = c.lossyDoubleIfPresent(.shares)
        price = c.lossyDoubleIfPresent(.price)
        amount = try c.lossyDouble(.amount)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

struct PerformancePoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let value: Double

    var dateValue: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: date) ?? Date()
    }

    init(date: String, value: Double) {
        self.date = date
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        value = try c.lossyDouble(.value)
    }

    enum CodingKeys: String, CodingKey { case date, value }
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
    let filename: String?
    let mimeType: String?
    let createdAt: String
    let name: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, title, type, period, filename, name, email
        case sizeKb = "size_kb"
        case mimeType = "mime_type"
        case createdAt = "created_at"
    }
}

// Mirrors withdrawal_requests — client request, admin approve/reject workflow.
struct WithdrawalRequest: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let amount: Double
    let unitsRedeemed: Double
    let unitPrice: Double
    let status: String
    let notes: String?
    let createdAt: String
    let processedAt: String?
    let name: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, notes, name, email
        case userId = "user_id"
        case unitsRedeemed = "units_redeemed"
        case unitPrice = "unit_price"
        case createdAt = "created_at"
        case processedAt = "processed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        amount = try c.lossyDouble(.amount)
        unitsRedeemed = try c.lossyDouble(.unitsRedeemed)
        unitPrice = try c.lossyDouble(.unitPrice)
        status = try c.decode(String.self, forKey: .status)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        processedAt = try c.decodeIfPresent(String.self, forKey: .processedAt)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
    }
}

// Mirrors deposit_requests — manual/wire deposit, admin confirm-receipt + invest workflow.
struct DepositRequest: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let amount: Double
    let status: String
    let unitsAllocated: Double?
    let unitPrice: Double?
    let filename: String?
    let notes: String?
    let createdAt: String
    let processedAt: String?
    let name: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, filename, notes, name, email
        case userId = "user_id"
        case unitsAllocated = "units_allocated"
        case unitPrice = "unit_price"
        case createdAt = "created_at"
        case processedAt = "processed_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        amount = try c.lossyDouble(.amount)
        status = try c.decode(String.self, forKey: .status)
        unitsAllocated = c.lossyDoubleIfPresent(.unitsAllocated)
        unitPrice = c.lossyDoubleIfPresent(.unitPrice)
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        processedAt = try c.decodeIfPresent(String.self, forKey: .processedAt)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        email = try c.decodeIfPresent(String.self, forKey: .email)
    }
}

struct InvestCashStatus: Codable {
    let cash: Double
    let configured: Bool
}

struct TradeResult: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let notional: String
    let status: String
    let orderId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case symbol, notional, status, error
        case orderId = "orderId"
    }
}

struct InvestResult: Codable {
    let success: Bool
    let amount: Double
    let trades: [TradeResult]
}

struct FeePreviewClient: Codable, Identifiable {
    var id: Int { userId }
    let userId: Int
    let name: String
    let email: String
    let feeAmount: Double
    let feeRate: Double
    let totalValue: Double

    enum CodingKeys: String, CodingKey {
        case userId = "userId"
        case name, email
        case feeAmount = "feeAmount"
        case feeRate = "feeRate"
        case totalValue = "totalValue"
    }
}

struct FeePreviewResult: Codable {
    let collected: Double
    let clients: [FeePreviewClient]
}

struct StripeDeposit: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let amount: Double
    let status: String
    let createdAt: String
    let name: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id, amount, status, name, email
        case userId = "user_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        userId = try c.decode(Int.self, forKey: .userId)
        amount = try c.lossyDouble(.amount)
        status = try c.decode(String.self, forKey: .status)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
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

struct AdminUser: Decodable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let createdAt: String
    let totalValue: Double?
    let dayChangePct: Double?
    let feeRate: Double?
    let lastFeeChargedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role
        case createdAt = "created_at"
        case totalValue = "total_value"
        case dayChangePct = "day_change_pct"
        case feeRate = "fee_rate"
        case lastFeeChargedAt = "last_fee_charged_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
        role = try c.decode(String.self, forKey: .role)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        totalValue = c.lossyDoubleIfPresent(.totalValue)
        dayChangePct = c.lossyDoubleIfPresent(.dayChangePct)
        feeRate = c.lossyDoubleIfPresent(.feeRate)
        lastFeeChargedAt = try c.decodeIfPresent(String.self, forKey: .lastFeeChargedAt)
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
