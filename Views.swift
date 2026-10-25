import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var store: Store
    @State private var week = currentWeek()

    var body: some View {
        NavigationStack {
            List {
                Picker("Неделя", selection: $week) {
                    Text("I неделя").tag(1)
                    Text("II неделя").tag(2)
                }.pickerStyle(.segmented)
                if let e = store.error { Text(e).font(.footnote).foregroundStyle(.orange) }
                ForEach(0..<6, id: \.self) { d in
                    let items = store.data.lessons.filter { $0.week == week && $0.day == d }
                    if !items.isEmpty || d < 5 {
                        Section(dayNames[d] + (week == currentWeek() && d == todayIndex() ? " · сегодня" : "")) {
                            if items.isEmpty { Text("Занятий нет").foregroundStyle(.secondary) }
                            ForEach(items) { l in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.subject).font(.headline)
                                    Text([l.time, l.room].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if let u = store.data.updated {
                    Text("Обновлено: \(u.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(group)
            .refreshable { await store.refresh() }
        }
        .task { await store.refresh() }
    }
}

struct HomeworkView: View {
    @EnvironmentObject var store: Store
    @State private var adding = false

    var sorted: [Homework] {
        store.data.homework.sorted { ($0.done ? 1 : 0, $0.due) < ($1.done ? 1 : 0, $1.due) }
    }

    var body: some View {
        NavigationStack {
            List {
                if sorted.isEmpty { Text("Заданий пока нет. Нажмите «+».").foregroundStyle(.secondary) }
                ForEach(sorted) { h in
                    Button { store.toggle(h) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: h.done ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.title).strikethrough(h.done)
                                Text(h.subject).font(.subheadline).foregroundStyle(.secondary)
                                Text(h.due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(!h.done && h.due.timeIntervalSinceNow < 86400 ? .red : .secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { store.remove(h) } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("Домашка")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { AddHomework() }
        }
    }
}

struct AddHomework: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var subject = subjects[0]
    @State private var title = ""
    @State private var due = Date().addingTimeInterval(86400)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Предмет", selection: $subject) { ForEach(subjects, id: \.self) { Text($0) } }
                TextField("Что задано", text: $title)
                DatePicker("Срок сдачи", selection: $due)
            }
            .navigationTitle("Новое задание")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        store.add(Homework(subject: subject, title: title, due: due))
                        dismiss()
                    }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
