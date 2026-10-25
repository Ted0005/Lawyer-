import Foundation

let group = "ЮФ2611"
let dayNames = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
let subjects = ["Правоохранительные органы", "Основы российской государственности", "Теория государства и права",
                "Конституционное право", "История государства и права России",
                "История государства и права зарубежных стран", "История России", "Философия",
                "Логика", "Иностранный язык", "Физкультура", "Другое"]

struct Lesson: Codable, Identifiable {
    var id = UUID()
    var week: Int      // 1 или 2
    var day: Int       // 0 = понедельник
    var time: String
    var subject: String
    var room: String
}

struct Homework: Codable, Identifiable {
    var id = UUID()
    var subject: String
    var title: String
    var due: Date
    var done = false
}

struct SavedData: Codable {
    var lessons: [Lesson] = []
    var updated: Date? = nil
    var homework: [Homework] = []
}

/// 26.10.2026 — I неделя, дальше недели чередуются
func currentWeek() -> Int {
    var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
    let ref = cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!
    let mon = cal.dateInterval(of: .weekOfYear, for: Date())!.start
    let diff = Int((mon.timeIntervalSince(ref) / 604800).rounded())
    return ((diff % 2) + 2) % 2 == 0 ? 1 : 2
}
func todayIndex() -> Int { (Calendar.current.component(.weekday, from: Date()) + 5) % 7 }

@MainActor
final class Store: ObservableObject {
    @Published var data = SavedData() { didSet { save() } }
    @Published var error: String?
    private let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("data.json")

    init() {
        if let d = try? Data(contentsOf: file), let s = try? JSONDecoder().decode(SavedData.self, from: d) { data = s }
    }
    private func save() { try? JSONEncoder().encode(data).write(to: file, options: .atomic) }

    func refresh() async {
        error = nil
        do {
            let lessons = try await ScheduleService.fetch(group: group)
            if lessons.isEmpty { error = "Не удалось разобрать расписание. Показано сохранённое."; return }
            data.lessons = lessons
            data.updated = Date()
        } catch {
            self.error = "Ошибка: " + error.localizedDescription
        }
    }

    func add(_ h: Homework) { data.homework.append(h); Notifier.schedule(h) }
    func toggle(_ h: Homework) {
        guard let i = data.homework.firstIndex(where: { $0.id == h.id }) else { return }
        data.homework[i].done.toggle()
        Notifier.schedule(data.homework[i])
    }
    func remove(_ h: Homework) { data.homework.removeAll { $0.id == h.id }; Notifier.cancel(h) }
}
