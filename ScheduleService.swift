import Foundation
import SwiftSoup

struct ScheduleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ScheduleService {
    static func fetch(group: String) async throws -> [Lesson] {
        var c = URLComponents(string: "https://s.kubsau.ru/")!
        c.queryItems = [URLQueryItem(name: "type_schedule", value: "1"), URLQueryItem(name: "val", value: group)]
        var req = URLRequest(url: c.url!, timeoutInterval: 20)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        req.setValue("ru-RU,ru;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let html = String(decoding: data, as: UTF8.self)
        let lessons = try parse(html)
        if lessons.isEmpty {
            let head = ((try? SwiftSoup.parse(html).text()) ?? "").prefix(150)
            throw ScheduleError(message: "Не удалось разобрать расписание (код \(code), \(html.count) симв.). Начало страницы: \(head)")
        }
        return lessons
    }

    /// Разметку не привязываем к тегам: ищем заголовки недель и дней по тексту, строки берём из любых tr.
    static func parse(_ html: String) throws -> [Lesson] {
        let doc = try SwiftSoup.parse(html)
        var week = 0, day = -1
        var out: [Lesson] = []
        for el in try doc.select("*").array() {
            let tag = el.tagName()
            if tag == "tr" {
                guard week > 0, day >= 0 else { continue }
                let cells = try el.select("td, th").array().map { try $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }
                guard let ti = cells.firstIndex(where: { $0.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) != nil }) else { continue }
                let rest = cells[(ti + 1)...].filter { !$0.isEmpty }
                guard let first = rest.first else { continue }
                var subject = first
                if subject.hasPrefix("Элективные курсы") { subject = "Элективные курсы по физкультуре" }
                let room = rest.dropFirst().joined(separator: ", ")
                let time = cells[ti].replacingOccurrences(of: " ", with: "–")
                out.append(Lesson(week: week, day: day, time: time, subject: subject, room: room))
            } else {
                var t = el.ownText().trimmingCharacters(in: .whitespacesAndNewlines)
                if t.isEmpty, tag.count == 2, tag.hasPrefix("h") { t = try el.text() }
                if t.hasPrefix("Первая неделя") { week = 1; day = -1 }
                else if t.hasPrefix("Вторая неделя") { week = 2; day = -1 }
                else if t.contains("|"), let i = dayNames.firstIndex(where: { t.hasPrefix($0) }) { day = i }
            }
        }
        return out
    }
}
