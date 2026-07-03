import SwiftUI

// 看板：今天必做 / 立即可做 / 本週做 / 低優先（欄位規則與網頁版一致）
struct KanbanView: View {
    @EnvironmentObject var store: AppStore

    struct Column: Identifiable {
        let id: String
        let label: String
        let colorHex: UInt32
        let filter: (UnblockItem) -> Bool
    }

    private var columns: [Column] {
        [
            Column(id: "urgent", label: "今天必做", colorHex: 0xEF4444) {
                !$0.done && $0.urgency == "urgent"
            },
            Column(id: "quick", label: "立即可做", colorHex: 0x2DD4A7) {
                !$0.done && $0.urgency != "urgent" && $0.phase == "quick-win"
            },
            Column(id: "soon", label: "本週做", colorHex: 0xD97706) {
                !$0.done && $0.urgency == "soon" && $0.phase != "quick-win"
            },
            Column(id: "low", label: "低優先", colorHex: 0x9CA3AF) {
                !$0.done && ($0.urgency == "whenever" || $0.urgency == nil) && $0.phase != "quick-win"
            },
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(columns) { col in
                        columnView(col)
                    }
                }
                .padding(16)
            }
            .background(Color.paper)
            .navigationTitle("看板")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.loadAll() }
        }
    }

    private func columnView(_ col: Column) -> some View {
        let colItems = store.items.filter(col.filter)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: col.colorHex))
                    .frame(width: 8, height: 8)
                Text(col.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: col.colorHex))
                    .textCase(.uppercase)
                Text("\(colItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if colItems.isEmpty {
                Text("無任務")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(colItems) { item in
                            cardView(item, currentColumn: col.id)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 240)
    }

    private func cardView(_ item: UnblockItem, currentColumn: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.text)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                if let urg = item.urgency, let meta = UrgencyMeta.all[urg], currentColumn != "urgent" {
                    TagPill(text: meta.label, colorHex: meta.colorHex)
                }
                if item.isClassified, let meta = StatusMeta.all[item.phase], currentColumn != "quick" {
                    TagPill(text: meta.label, colorHex: meta.colorHex)
                }
                if let cat = store.categoryById(item.categoryId) {
                    TagPill(text: cat.display, colorHex: 0xA09E9A)
                }
            }
        }
        .padding(12)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contextMenu {
            Button { store.completeItem(item) } label: {
                Label("標記完成", systemImage: "checkmark.circle")
            }
            Menu {
                ForEach(columns.filter { $0.id != currentColumn }) { col in
                    Button(col.label) { move(item, to: col.id, from: currentColumn) }
                }
            } label: {
                Label("移到…", systemImage: "arrow.right.circle")
            }
            Button(role: .destructive) { store.deleteItem(item) } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }

    /// 欄位 → urgency/phase 更新（與網頁版 COL_UPDATE 一致）
    private func move(_ item: UnblockItem, to colId: String, from oldColId: String) {
        var fields: [String: Any] = [:]
        switch colId {
        case "urgent": fields["urgency"] = "urgent"
        case "quick":  fields["urgency"] = "soon"; fields["phase"] = "quick-win"
        case "soon":   fields["urgency"] = "soon"
        case "low":    fields["urgency"] = "whenever"
        default: return
        }
        // 從「立即可做」欄拖出且新欄不是 quick → 改為延後處理
        if oldColId == "quick" && colId != "quick" && item.phase == "quick-win" {
            fields["phase"] = "defer"
        }
        store.updateItem(item, fields: fields)
    }
}
