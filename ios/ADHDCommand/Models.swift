import Foundation

// MARK: - 今日任務（Supabase `tasks` 表）

struct TodayTask: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var tag: String?
    var done: Bool
    var sortOrder: Int?
    var completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, text, tag, done
        case sortOrder = "sort_order"
        case completedAt = "completed_at"
    }

    init(id: String, text: String, tag: String?, done: Bool, sortOrder: Int?, completedAt: String?) {
        self.id = id
        self.text = text
        self.tag = tag
        self.done = done
        self.sortOrder = sortOrder
        self.completedAt = completedAt
    }

    // 容錯解碼：舊資料可能有 null 欄位
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
    }
}

// MARK: - 腦袋清空項目（Supabase `unblock_items` 表）
// phase: dump（未分類）| blocker | quick-win | defer | noise | waiting

struct UnblockItem: Identifiable, Codable, Equatable {
    var id: String
    var text: String
    var phase: String
    var impact: Int?
    var effort: Int?
    var isBlocker: Bool
    var done: Bool
    var urgency: String?      // urgent | soon | whenever
    var categoryId: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, text, phase, impact, effort, done, urgency
        case isBlocker = "is_blocker"
        case categoryId = "category_id"
        case sortOrder = "sort_order"
    }

    init(id: String, text: String, phase: String, impact: Int?, effort: Int?,
         isBlocker: Bool, done: Bool, urgency: String?, categoryId: String?, sortOrder: Int?) {
        self.id = id
        self.text = text
        self.phase = phase
        self.impact = impact
        self.effort = effort
        self.isBlocker = isBlocker
        self.done = done
        self.urgency = urgency
        self.categoryId = categoryId
        self.sortOrder = sortOrder
    }

    // 容錯解碼：舊資料可能有 null 欄位
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? "dump"
        impact = try c.decodeIfPresent(Int.self, forKey: .impact)
        effort = try c.decodeIfPresent(Int.self, forKey: .effort)
        isBlocker = try c.decodeIfPresent(Bool.self, forKey: .isBlocker) ?? false
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        urgency = try c.decodeIfPresent(String.self, forKey: .urgency)
        categoryId = try c.decodeIfPresent(String.self, forKey: .categoryId)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder)
    }

    var isClassified: Bool { phase != "dump" }
}

struct UnblockCategory: Identifiable, Codable, Equatable {
    var id: String
    var emoji: String?
    var label: String
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, emoji, label
        case sortOrder = "sort_order"
    }

    var display: String { "\(emoji ?? "📌") \(label)" }
}

// MARK: - 分類邏輯（與網頁版 classify() 一致）

func classifyItem(impact: Int, effort: Int, isBlocker: Bool) -> String {
    if isBlocker { return "blocker" }
    if impact == 2 && effort <= 1 { return "quick-win" }
    if impact == 2 && effort == 2 { return "defer" }
    if impact <= 1 { return "noise" }
    return "quick-win"
}

// MARK: - 顯示用 meta

struct StatusMeta {
    let label: String
    let colorHex: UInt32

    static let all: [String: StatusMeta] = [
        "blocker":   StatusMeta(label: "解鎖任務", colorHex: 0xFF6B35),
        "quick-win": StatusMeta(label: "立即可做", colorHex: 0x2DD4A7),
        "defer":     StatusMeta(label: "延後處理", colorHex: 0xA78BFA),
        "noise":     StatusMeta(label: "低優先",   colorHex: 0x6B7280),
        "waiting":   StatusMeta(label: "等待中",   colorHex: 0xFBBF24),
    ]
}

struct UrgencyMeta {
    let label: String
    let colorHex: UInt32

    static let all: [String: UrgencyMeta] = [
        "urgent":   UrgencyMeta(label: "🔴 今天必做", colorHex: 0xEF4444),
        "soon":     UrgencyMeta(label: "🟡 本週內",   colorHex: 0xD97706),
        "whenever": UrgencyMeta(label: "⚪ 隨時",     colorHex: 0xA09E9A),
    ]
}
