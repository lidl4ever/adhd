import Foundation
import SwiftUI

// 全 app 共用資料層 — 樂觀更新：本地先改、畫面立即反應，背景同步 Supabase，
// 失敗時重新載入還原（與網頁版行為一致）
@MainActor
final class AppStore: ObservableObject {
    @Published var tasks: [TodayTask] = []
    @Published var items: [UnblockItem] = []
    @Published var categories: [UnblockCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 載入

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        async let t: () = loadTasks()
        async let i: () = loadItems()
        async let c: () = loadCategories()
        _ = await (t, i, c)
    }

    func loadTasks() async {
        do { tasks = try await Supabase.select("tasks", as: [TodayTask].self) }
        catch { report(error) }
    }

    func loadItems() async {
        do { items = try await Supabase.select("unblock_items", as: [UnblockItem].self) }
        catch { report(error) }
    }

    func loadCategories() async {
        do {
            categories = try await Supabase.select(
                "unblock_categories", as: [UnblockCategory].self, order: "sort_order.asc")
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    private func sync(_ op: @escaping () async throws -> Void, reload: @escaping () async -> Void) {
        Task {
            do { try await op() }
            catch {
                self.report(error)
                await reload()
            }
        }
    }

    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - 今日任務

    func toggleTask(_ task: TodayTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].done.toggle()
        let done = tasks[idx].done
        let json: [String: Any] = done
            ? ["done": true, "completed_at": Self.isoNow()]
            : ["done": false, "completed_at": NSNull()]
        sync({
            try await Supabase.request("tasks", method: "PATCH",
                query: [URLQueryItem(name: "id", value: "eq.\(task.id)")], json: json)
        }, reload: { await self.loadTasks() })
    }

    func deleteTask(_ task: TodayTask) {
        tasks.removeAll { $0.id == task.id }
        sync({
            try await Supabase.request("tasks", method: "DELETE",
                query: [URLQueryItem(name: "id", value: "eq.\(task.id)")])
        }, reload: { await self.loadTasks() })
    }

    func addTask(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let temp = TodayTask(id: "temp-\(UUID().uuidString)", text: trimmed, tag: "",
                             done: false, sortOrder: tasks.count, completedAt: nil)
        tasks.append(temp)
        Task {
            do {
                let data = try await Supabase.request("tasks", method: "POST",
                    json: ["text": trimmed, "tag": "", "done": false, "sort_order": tasks.count - 1],
                    prefer: "return=representation")
                let inserted = try JSONDecoder().decode([TodayTask].self, from: data)
                if let real = inserted.first,
                   let idx = tasks.firstIndex(where: { $0.id == temp.id }) {
                    tasks[idx] = real
                }
            } catch {
                report(error)
                await loadTasks()
            }
        }
    }

    func clearDoneTasks() {
        tasks.removeAll { $0.done }
        sync({
            try await Supabase.request("tasks", method: "DELETE",
                query: [URLQueryItem(name: "done", value: "eq.true")])
        }, reload: { await self.loadTasks() })
    }

    // MARK: - 腦袋清空項目

    func addItems(lines: [String]) {
        let clean = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !clean.isEmpty else { return }
        let base = items.count
        for (i, line) in clean.enumerated() {
            items.append(UnblockItem(id: "temp-\(UUID().uuidString)", text: line, phase: "dump",
                                     impact: nil, effort: nil, isBlocker: false, done: false,
                                     urgency: nil, categoryId: nil, sortOrder: base + i))
        }
        let rows: [[String: Any]] = clean.enumerated().map { i, line in
            ["text": line, "phase": "dump", "is_blocker": false, "done": false, "sort_order": base + i]
        }
        Task {
            do {
                try await Supabase.request("unblock_items", method: "POST", jsonArray: rows)
                await loadItems() // 換掉暫時 id
            } catch {
                report(error)
                await loadItems()
            }
        }
    }

    func updateItem(_ item: UnblockItem, fields: [String: Any]) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            var it = items[idx]
            if let v = fields["phase"] as? String { it.phase = v }
            if let v = fields["urgency"] as? String { it.urgency = v }
            if let v = fields["impact"] as? Int { it.impact = v }
            if let v = fields["effort"] as? Int { it.effort = v }
            if let v = fields["is_blocker"] as? Bool { it.isBlocker = v }
            if let v = fields["done"] as? Bool { it.done = v }
            if fields.keys.contains("category_id") {
                it.categoryId = fields["category_id"] as? String
            }
            items[idx] = it
        }
        sync({
            try await Supabase.request("unblock_items", method: "PATCH",
                query: [URLQueryItem(name: "id", value: "eq.\(item.id)")], json: fields)
        }, reload: { await self.loadItems() })
    }

    func completeItem(_ item: UnblockItem) {
        updateItem(item, fields: ["done": true])
    }

    func deleteItem(_ item: UnblockItem) {
        items.removeAll { $0.id == item.id }
        sync({
            try await Supabase.request("unblock_items", method: "DELETE",
                query: [URLQueryItem(name: "id", value: "eq.\(item.id)")])
        }, reload: { await self.loadItems() })
    }

    // MARK: - 挑選專注任務（與網頁版 pickFocus 一致的優先序）

    func pickFocusItem(excluding excludedId: String? = nil) -> UnblockItem? {
        let pool = items.filter {
            $0.isClassified && $0.phase != "waiting" && !$0.done && $0.id != excludedId
        }
        func score(_ t: UnblockItem) -> Int {
            let urg = ["urgent": 0, "soon": 1, "whenever": 2][t.urgency ?? ""] ?? 2
            let status = ["blocker": 0, "quick-win": 1, "defer": 2, "noise": 3][t.phase] ?? 4
            return status * 10 + urg
        }
        return pool.min { score($0) < score($1) }
    }

    func categoryById(_ id: String?) -> UnblockCategory? {
        guard let id = id else { return nil }
        return categories.first { $0.id == id }
    }
}
