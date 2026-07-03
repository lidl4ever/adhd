import Foundation
import SwiftUI
import UserNotifications

// 時間戳計時器：以結束時刻（endAt）計算剩餘，App 進背景/鎖屏不會凍結；
// 到點時由系統推送本地通知 — 這是原生 app 相對網頁版最大的優勢
@MainActor
final class PomodoroModel: ObservableObject {
    @Published var totalSeconds: Int
    @Published var remaining: Int
    @Published var isRunning = false
    @Published var isDone = false
    @Published var todayCount: Int = 0

    /// work 模式完成才累積 🍅；rest 模式不算
    var mode: Mode
    enum Mode { case work, rest }

    private var endAt: Date?
    private var ticker: Timer?
    private let notificationId: String
    private let countsPomodoros: Bool

    init(seconds: Int, mode: Mode = .work, notificationId: String, countsPomodoros: Bool = false) {
        self.totalSeconds = seconds
        self.remaining = seconds
        self.mode = mode
        self.notificationId = notificationId
        self.countsPomodoros = countsPomodoros
        if countsPomodoros { todayCount = Self.loadCount() }
    }

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func select(minutes: Int, mode: Mode) {
        stop()
        self.mode = mode
        totalSeconds = minutes * 60
        remaining = totalSeconds
        isDone = false
    }

    func startPause() {
        if isRunning {
            syncRemaining()
            stop()
        } else {
            isDone = false
            endAt = Date().addingTimeInterval(TimeInterval(remaining))
            isRunning = true
            scheduleNotification(after: TimeInterval(remaining))
            ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    func reset() {
        stop()
        remaining = totalSeconds
        isDone = false
    }

    /// 從背景回前景時呼叫，立即校正顯示
    func syncRemaining() {
        guard let endAt = endAt else { return }
        remaining = max(0, Int(endAt.timeIntervalSinceNow.rounded()))
    }

    var progress: Double {
        totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0
    }

    var displayTime: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    private func tick() {
        syncRemaining()
        if remaining <= 0 {
            stop()
            isDone = true
            if countsPomodoros && mode == .work {
                todayCount += 1
                Self.saveCount(todayCount)
            }
            remaining = totalSeconds
        }
    }

    private func stop() {
        ticker?.invalidate()
        ticker = nil
        isRunning = false
        endAt = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    private func scheduleNotification(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = mode == .work ? "🍅 完成！" : "⏰ 休息結束"
        content.body = mode == .work ? "休息一下，你贏了這 25 分鐘。" : "繼續，選一件事開始。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let req = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - 每日 🍅 計數（存本機）

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "pomCount-\(f.string(from: Date()))"
    }

    private static func loadCount() -> Int {
        UserDefaults.standard.integer(forKey: todayKey())
    }

    private static func saveCount(_ n: Int) {
        UserDefaults.standard.set(n, forKey: todayKey())
    }
}
