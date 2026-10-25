import Foundation
import SwiftSoup

enum ScheduleService {
    static func fetch(group: String) async throws -> [Lesson] {
        var c = URLComponents(string: "https://s.kubsau.ru/")!
        c.queryItems = [URLQueryItem(name: "type_schedule", value: "1"), URLQueryItem(name: "val", value: group)]
        let req = URLRequest(url: c.url!, timeoutInterval: 20)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parse(String(decoding: data, as: UTF8.self))
    }

    /// Ждём разметку: заголовок недели (h3), заголовок дня (h4), строки таблицы (tr: время, ?, предмет, аудитория).
    static func parse(_ html: String) throws -> [Lesson] {
        let doc = try SwiftSoup.parse(html)
        var week = 0, day = -1
        var out: [Lesson] = []
        for el in try doc.select("h3, h4, tr").array() {
            let text = try el.text()
            switch el.tagName() {
            case "h3":
                if text.contains("Первая") { week = 1 } else if text.contains("Вторая") { week = 2 } else { week = 0 }
                day = -1
            case "h4":
                day = dayNames.firstIndex { text.hasPrefix($0) } ?? -1
            default:
                guard week > 0, day >= 0 else { continue }
                let tds = try el.select("td").array()
                guard tds.count >= 3 else { continue }
                var subject = try tds[2].text().trimmingCharacters(in: .whitespaces)
                if subject.isEmpty { continue }
                if subject.hasPrefix("Элективные курсы") { subject = "Элективные курсы по физкультуре" }
                let time = try tds[0].text().replacingOccurrences(of: " ", with: "–")
                let room = tds.count > 3 ? try tds[3].text() : ""
                out.append(Lesson(week: week, day: day, time: time, subject: subject, room: room))
            }
        }
        return out
    }
}
