import SwiftUI

// 腦袋清空：Dump（倒出）→ Triage（分類）→ Focus（5 分鐘啟動）
struct UnblockView: View {
    @EnvironmentObject var store: AppStore

    enum Phase { case dump, triage, focus }
    @State private var phase: Phase = .dump
    @State private var focusItem: UnblockItem?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .dump:
                    DumpPhaseView(startTriage: {
                        if unclassified.isEmpty { startFocus() } else { phase = .triage }
                    })
                case .triage:
                    TriagePhaseView(
                        finished: { startFocus() },
                        back: { phase = .dump }
                    )
                case .focus:
                    if let item = focusItem {
                        FocusPhaseView(
                            item: item,
                            completed: {
                                store.completeItem(item)
                                phase = .dump
                            },
                            skip: {
                                store.updateItem(item, fields: ["phase": "waiting"])
                                startFocus(excluding: item.id)
                            },
                            back: { phase = .dump }
                        )
                    } else {
                        Text("沒有可專注的任務")
                            .foregroundColor(.secondary)
                            .onAppear { phase = .dump }
                    }
                }
            }
            .background(Color.paper)
            .navigationTitle("腦袋清空")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var unclassified: [UnblockItem] {
        store.items.filter { $0.phase == "dump" && !$0.done }
    }

    private func startFocus(excluding id: String? = nil) {
        focusItem = store.pickFocusItem(excluding: id)
        phase = .focus
    }
}

// MARK: - Dump

struct DumpPhaseView: View {
    @EnvironmentObject var store: AppStore
    let startTriage: () -> Void

    @State private var input = ""
    @State private var showDone = false

    private var blockers: [UnblockItem] {
        store.items.filter { $0.phase == "blocker" && !$0.done }
    }
    private var unclassified: [UnblockItem] {
        store.items.filter { $0.phase == "dump" && !$0.done }
    }
    private var classified: [UnblockItem] {
        store.items.filter { $0.isClassified && $0.phase != "blocker" && !$0.done }
    }
    private var doneItems: [UnblockItem] {
        store.items.filter { $0.done }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("把腦袋裡所有還沒做的事倒出來。\n不用整理，不用排序，一行一件事。")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                TextEditor(text: $input)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    Button("加入清單") { addLines() }
                        .buttonStyle(.bordered)
                    Button("加入並立刻分類 →") {
                        addLines()
                        startTriage()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                }

                if !blockers.isEmpty {
                    sectionHeader("🔴 解鎖任務 — 做完才能推進其他事")
                    ForEach(blockers) { ItemPillView(item: $0) }
                }

                ForEach(groupedClassified) { group in
                    sectionHeader(group.id)
                    ForEach(group.items) { ItemPillView(item: $0) }
                }

                if !unclassified.isEmpty {
                    sectionHeader("待分類 · \(unclassified.count) 件")
                    ForEach(unclassified) { ItemPillView(item: $0) }
                    Button("開始分類 (\(unclassified.count) 件) →") { startTriage() }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }

                if unclassified.isEmpty && !(blockers.isEmpty && classified.isEmpty) {
                    Button("選出今天要做的 →") { startTriage() }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }

                if !doneItems.isEmpty {
                    Button {
                        withAnimation { showDone.toggle() }
                    } label: {
                        Text("\(showDone ? "▾" : "▸") 已完成 \(doneItems.count) 件")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    if showDone {
                        ForEach(doneItems) { ItemPillView(item: $0).opacity(0.5) }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await store.loadAll() }
    }

    struct ItemGroup: Identifiable {
        let id: String   // 顯示標籤兼 id
        let items: [UnblockItem]
    }

    /// 依分類分組（排序：分類 sort_order，未分類最後；組內 urgent 優先）
    private var groupedClassified: [ItemGroup] {
        var result: [ItemGroup] = []
        let urgOrder = ["urgent": 0, "soon": 1, "whenever": 2]
        func sorted(_ arr: [UnblockItem]) -> [UnblockItem] {
            arr.sorted { (urgOrder[$0.urgency ?? ""] ?? 3) < (urgOrder[$1.urgency ?? ""] ?? 3) }
        }
        for cat in store.categories {
            let group = classified.filter { $0.categoryId == cat.id }
            if !group.isEmpty { result.append(ItemGroup(id: cat.display, items: sorted(group))) }
        }
        let uncat = classified.filter { item in
            item.categoryId == nil || !store.categories.contains { $0.id == item.categoryId }
        }
        if !uncat.isEmpty { result.append(ItemGroup(id: "未分類", items: sorted(uncat))) }
        return result
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.top, 8)
    }

    private func addLines() {
        store.addItems(lines: input.components(separatedBy: "\n"))
        input = ""
    }
}

// MARK: - 任務 pill

struct ItemPillView: View {
    @EnvironmentObject var store: AppStore
    let item: UnblockItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { store.completeItem(item) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.done ? Color(hex: 0x2DD4A7) : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(item.done)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(size: 13))
                    .strikethrough(item.done)
                    .foregroundColor(item.done ? .secondary : .primary)
                HStack(spacing: 4) {
                    if let urg = item.urgency, let meta = UrgencyMeta.all[urg] {
                        TagPill(text: meta.label, colorHex: meta.colorHex)
                    }
                    if item.isClassified, let meta = StatusMeta.all[item.phase] {
                        TagPill(text: meta.label, colorHex: meta.colorHex)
                    }
                    if let cat = store.categoryById(item.categoryId) {
                        TagPill(text: cat.display, colorHex: 0xA09E9A)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button(role: .destructive) { store.deleteItem(item) } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Triage

struct TriagePhaseView: View {
    @EnvironmentObject var store: AppStore
    let finished: () -> Void
    let back: () -> Void

    @State private var urgency: String?
    @State private var categoryId: String?
    @State private var impact: Int?
    @State private var effort: Int?
    @State private var isBlocker = false
    @State private var doneCount = 0

    private var queue: [UnblockItem] {
        store.items.filter { $0.phase == "dump" && !$0.done }
    }
    private var current: UnblockItem? { queue.first }

    var body: some View {
        ScrollView {
            if let item = current {
                VStack(alignment: .leading, spacing: 16) {
                    Text("分類 · 第 \(doneCount + 1) 件，剩 \(queue.count) 件 — 快速選就好")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(item.text)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Toggle("這件事做完會解鎖其他任務？", isOn: $isBlocker)
                        .font(.system(size: 13))
                        .tint(Color(hex: 0xFF6B35))

                    choiceSection("時間壓力？", options: [
                        ("urgent", "🔴 今天必做"), ("soon", "🟡 本週內"), ("whenever", "⚪ 隨時"),
                    ], selection: $urgency)

                    if !store.categories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("屬於哪類？")
                            FlowChoices(
                                options: store.categories.map { ($0.id, $0.display) } + [("__none__", "其他")],
                                selection: Binding(
                                    get: { categoryId ?? "__none__" },
                                    set: { categoryId = $0 == "__none__" ? nil : $0 }
                                )
                            )
                        }
                    }

                    choiceSectionInt("做了有幫助嗎？", options: [
                        (0, "沒什麼用"), (1, "有些用"), (2, "很有用"),
                    ], selection: $impact)

                    choiceSectionInt("做起來難嗎？", options: [
                        (0, "很簡單"), (1, "有點難"), (2, "很難"),
                    ], selection: $effort)

                    Button("下一件 →") { confirm(item) }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                        .frame(maxWidth: .infinity)
                        .disabled(urgency == nil || impact == nil || effort == nil)

                    Button("← 回清單") { back() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            } else {
                VStack(spacing: 16) {
                    Text("分類完成！")
                        .foregroundColor(.secondary)
                    Button("選出今天要做的 →") { finished() }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }
                .padding(40)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }

    private func choiceSection(_ title: String, options: [(String, String)], selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            HStack(spacing: 6) {
                ForEach(options.indices, id: \.self) { i in
                    ChoiceButton(label: options[i].1, selected: selection.wrappedValue == options[i].0) {
                        selection.wrappedValue = options[i].0
                    }
                }
            }
        }
    }

    private func choiceSectionInt(_ title: String, options: [(Int, String)], selection: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            HStack(spacing: 6) {
                ForEach(options.indices, id: \.self) { i in
                    ChoiceButton(label: options[i].1, selected: selection.wrappedValue == options[i].0) {
                        selection.wrappedValue = options[i].0
                    }
                }
            }
        }
    }

    private func confirm(_ item: UnblockItem) {
        guard let urg = urgency, let imp = impact, let eff = effort else { return }
        let newPhase = classifyItem(impact: imp, effort: eff, isBlocker: isBlocker)
        var fields: [String: Any] = [
            "urgency": urg, "impact": imp, "effort": eff,
            "is_blocker": isBlocker, "phase": newPhase,
        ]
        if let cid = categoryId {
            fields["category_id"] = cid
        } else {
            fields["category_id"] = NSNull()
        }
        store.updateItem(item, fields: fields)
        doneCount += 1
        urgency = nil; categoryId = nil; impact = nil; effort = nil; isBlocker = false
        if queue.isEmpty { finished() }
    }
}

struct ChoiceButton: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.gold.opacity(0.15) : Color.panel)
                .foregroundColor(selected ? .gold : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selected ? Color.gold : Color.primary.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 簡單換行排列的選項組（分類可能超過一行）
struct FlowChoices: View {
    let options: [(String, String)]
    @Binding var selection: String

    var body: some View {
        let rows = options.chunked(into: 2)
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(rows[r].indices, id: \.self) { c in
                        ChoiceButton(label: rows[r][c].1, selected: selection == rows[r][c].0) {
                            selection = rows[r][c].0
                        }
                    }
                }
            }
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Focus（5 分鐘啟動）

struct FocusPhaseView: View {
    @EnvironmentObject var store: AppStore
    let item: UnblockItem
    let completed: () -> Void
    let skip: () -> Void
    let back: () -> Void

    @StateObject private var timer = PomodoroModel(
        seconds: 300, mode: .work, notificationId: "unblock-focus"
    )
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 6) {
                    if let meta = StatusMeta.all[item.phase] {
                        TagPill(text: meta.label, colorHex: meta.colorHex)
                    }
                    if let urg = item.urgency, let meta = UrgencyMeta.all[urg] {
                        TagPill(text: meta.label, colorHex: meta.colorHex)
                    }
                }

                Text("現在只做這一件")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: timer.progress)
                        .stroke(
                            timer.isDone ? Color(hex: 0x2DD4A7) : Color(hex: 0xFF6B35),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(timer.isDone ? "完成" : timer.displayTime)
                            .font(.system(size: 32, weight: .light, design: .monospaced))
                            .foregroundColor(timer.isDone ? Color(hex: 0x2DD4A7) : .primary)
                        Text("5 分鐘")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 180, height: 180)
                .animation(.linear(duration: 0.5), value: timer.progress)

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.text)
                        .font(.system(size: 15))
                    Text("只做第一步。不用做完。只要開始。")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(spacing: 8) {
                    if !timer.isDone {
                        Button(timer.isRunning ? "暫停" : "開始 5 分鐘") { timer.startPause() }
                            .buttonStyle(.borderedProminent)
                            .tint(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    Button("✓ 做完了") { completed() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("換一件") { skip() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("回到清單") { back() }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { timer.syncRemaining() }
        }
    }
}
