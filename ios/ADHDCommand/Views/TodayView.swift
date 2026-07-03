import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var pomodoro = PomodoroModel(
        seconds: 25 * 60, mode: .work, notificationId: "pomodoro", countsPomodoros: true
    )
    @AppStorage("focusTask") private var focusTask = ""
    @AppStorage("runwayDeadline") private var runwayDeadline = "2026-06-30"
    @Environment(\.scenePhase) private var scenePhase

    @State private var newTaskText = ""
    @State private var showDone = false
    @State private var editingDeadline = false
    @State private var deadlineInput = ""
    @State private var selectedMinutes = 25

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    runwayBar
                    focusZone
                    taskPanel
                }
                .padding(16)
            }
            .background(Color.paper)
            .navigationTitle("今日指揮中心")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.loadAll() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { pomodoro.syncRemaining() }
        }
        .alert("生活費跑道截止日", isPresented: $editingDeadline) {
            TextField("YYYY-MM-DD", text: $deadlineInput)
            Button("儲存") {
                let v = deadlineInput.trimmingCharacters(in: .whitespaces)
                if v.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                    runwayDeadline = v
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("以截止日計算剩餘天數")
        }
    }

    // MARK: - Runway

    private var runwayDaysLeft: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: runwayDeadline) else { return 0 }
        let end = Calendar.current.startOfDay(for: d).addingTimeInterval(86400)
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return max(0, days)
    }

    private var runwayBar: some View {
        Button {
            deadlineInput = runwayDeadline
            editingDeadline = true
        } label: {
            HStack(spacing: 10) {
                Text("生活費跑道")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(hex: 0x22C55E), Color(hex: 0xF59E0B), Color(hex: 0xEF4444)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, Double(runwayDaysLeft) / 65.0))
                    }
                }
                .frame(height: 4)
                Text("\(runwayDaysLeft) 天")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: 0xF59E0B))
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Focus zone + 番茄鐘

    private var focusZone: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("現在只做這一件事")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gold)
                .textCase(.uppercase)

            TextField("輸入今天要專注的任務…", text: $focusTask)
                .font(.system(size: 19, weight: .medium))

            HStack(spacing: 14) {
                Text(pomodoro.displayTime)
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .foregroundColor(pomodoro.isRunning ? .gold : .primary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button(pomodoro.isRunning ? "暫停" : "開始") { pomodoro.startPause() }
                            .buttonStyle(.borderedProminent)
                            .tint(.gold)
                        Button("重設") { pomodoro.reset() }
                            .buttonStyle(.bordered)
                    }
                    HStack(spacing: 6) {
                        modePill(25, .work)
                        modePill(5, .rest)
                        modePill(15, .rest)
                        Spacer()
                        Text("今日 \(pomodoro.todayCount) 🍅")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gold.opacity(0.4), lineWidth: 1)
        )
    }

    private func modePill(_ minutes: Int, _ mode: PomodoroModel.Mode) -> some View {
        Button("\(minutes)") {
            selectedMinutes = minutes
            pomodoro.select(minutes: minutes, mode: mode)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(selectedMinutes == minutes ? Color.primary.opacity(0.1) : Color.clear)
        .foregroundColor(selectedMinutes == minutes ? .primary : .secondary)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - 今日任務

    private var activeTasks: [TodayTask] { store.tasks.filter { !$0.done } }
    private var doneTasks: [TodayTask] { store.tasks.filter { $0.done } }

    private var taskPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日任務 — 選一件開始")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if !doneTasks.isEmpty {
                    Text("\(doneTasks.count)/\(store.tasks.count) 完成")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            ForEach(activeTasks) { task in
                taskRow(task)
            }

            if !doneTasks.isEmpty {
                Button {
                    withAnimation { showDone.toggle() }
                } label: {
                    Text("\(showDone ? "▾" : "▸") 已完成 \(doneTasks.count) 件")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if showDone {
                    ForEach(doneTasks) { task in
                        taskRow(task).opacity(0.5)
                    }
                    Button("清除已完成") { store.clearDoneTasks() }
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                TextField("加入今日任務…", text: $newTaskText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .onSubmit(submitTask)
                Button(action: submitTask) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
        .panel()
    }

    private func submitTask() {
        store.addTask(text: newTaskText)
        newTaskText = ""
    }

    private func taskRow(_ task: TodayTask) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { store.toggleTask(task) } label: {
                Image(systemName: task.done ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.done ? Color(hex: 0x22C55E) : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.text)
                .font(.system(size: 14))
                .foregroundColor(task.done ? .secondary : .primary)
                .strikethrough(task.done)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tag = task.tag, tag == "hot" {
                TagPill(text: "🔴 急", colorHex: 0xEF4444)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button(role: .destructive) { store.deleteTask(task) } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}
