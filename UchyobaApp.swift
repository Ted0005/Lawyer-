import SwiftUI

@main
struct UchyobaApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            TabView {
                ScheduleView().tabItem { Label("Расписание", systemImage: "calendar") }
                HomeworkView().tabItem { Label("Домашка", systemImage: "checklist") }
            }
            .environmentObject(store)
            .onAppear { Notifier.ask() }
        }
    }
}
