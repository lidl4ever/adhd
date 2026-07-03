import SwiftUI

@main
struct ADHDCommandApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    PomodoroModel.requestPermission()
                    await store.loadAll()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "sun.max") }
            UnblockView()
                .tabItem { Label("清空", systemImage: "brain.head.profile") }
            KanbanView()
                .tabItem { Label("看板", systemImage: "rectangle.split.3x1") }
        }
        .tint(.gold)
        .overlay(alignment: .bottom) {
            if let msg = store.errorMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0xEF4444).opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.bottom, 60)
                    .onTapGesture { store.errorMessage = nil }
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        store.errorMessage = nil
                    }
            }
        }
    }
}
