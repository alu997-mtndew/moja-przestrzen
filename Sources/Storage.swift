import Foundation

enum Segment: Int, CaseIterable, Identifiable {
    case title, daily, weekly, problems, behavior, commandments, ideas, archive
    var id: Int { rawValue }
    var name: String {
        switch self {
        case .title: "Moja przestrzeń"
        case .daily: "Codzienne"
        case .weekly: "Tygodniowe"
        case .problems: "Do przespania"
        case .behavior: "Moje zachowania"
        case .commandments: "Przykazania Martyny kochania"
        case .ideas: "Myśli i pomysły"
        case .archive: "Archiwum"
        }
    }
}

enum Period: String, Codable, CaseIterable, Identifiable {
    case daily, weekly
    var id: Self { self }
    var archiveLabel: String { self == .daily ? "Dni" : "Tygodnie" }
    var temporaryLabel: String { self == .daily ? "Tylko dzisiaj" : "Tylko w tym tygodniu" }
    var component: Calendar.Component { self == .daily ? .day : .weekOfYear }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    func start(_ date: Date) -> Date {
        Self.calendar.dateInterval(of: component, for: date)!.start
    }

    static func dateLabel(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    func label(_ date: Date) -> String {
        let first = start(date)
        if self == .daily { return Self.dateLabel(first, format: "d MMMM yyyy") }
        let last = Self.calendar.date(byAdding: .day, value: 6, to: first)!
        return "\(Self.dateLabel(first, format: "d MMM")) – \(Self.dateLabel(last, format: "d MMM yyyy"))"
    }

    func year(_ date: Date) -> Int {
        Self.calendar.component(self == .daily ? .year : .yearForWeekOfYear, from: date)
    }
}

enum TaskKind: String, Codable, CaseIterable, Identifiable {
    case recurring, temporary
    var id: Self { self }
    func label(_ period: Period) -> String { self == .recurring ? "Stałe" : period.temporaryLabel }
}

struct TaskRevision: Codable, Identifiable {
    var id = UUID()
    var text: String
    var kind: TaskKind
    var start: Date
    var end: Date?
}

struct Duty: Codable, Identifiable {
    var id = UUID()
    var period: Period
    var revisions: [TaskRevision]

    func revision(at start: Date) -> TaskRevision? {
        revisions.last { $0.start <= start && ($0.end.map { start < $0 } ?? true) }
    }

    mutating func replace(from start: Date, with revision: TaskRevision?) {
        revisions.removeAll { $0.start >= start }
        if let last = revisions.indices.last, revisions[last].end.map({ $0 > start }) ?? true {
            revisions[last].end = start
        }
        if let revision { revisions.append(revision) }
    }
}

enum NoteKind: String, Codable {
    case problem, behavior, commandment, idea
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Niski", medium = "Średni", high = "Wysoki"
    var id: Self { self }
}

struct Reflection: Codable, Identifiable {
    var id = UUID()
    var text: String
    var createdAt: Date
}

struct Note: Codable, Identifiable {
    var id = UUID()
    var kind: NoteKind
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var priority: Priority?
    var reflections: [Reflection]?
}

enum StorageError: LocalizedError {
    case invalidBackup, unsupportedVersion, unavailable

    var errorDescription: String? {
        switch self {
        case .invalidBackup: "Plik nie zawiera poprawnej kopii danych aplikacji."
        case .unsupportedVersion: "Ta kopia pochodzi z innej wersji formatu."
        case .unavailable: "Dane lokalne są niedostępne. Zamknij aplikację i spróbuj ponownie."
        }
    }
}

struct Store: Codable {
    static let formatID = "pl.dawidp.mojaprzestrzen.backup"
    var format = Self.formatID
    var version = 1
    var duties: [Duty] = []
    var notes: [Note] = []

    func tasks(_ period: Period, _ kind: TaskKind, at date: Date) -> [(Duty, TaskRevision)] {
        let start = period.start(date)
        return duties.compactMap { duty in
            guard duty.period == period, let revision = duty.revision(at: start), revision.kind == kind
            else { return nil }
            return (duty, revision)
        }
    }

    func notes(of kind: NoteKind) -> [Note] {
        let selected = notes.filter { $0.kind == kind }
        if kind == .commandment { return selected }
        return selected.sorted {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt > $1.createdAt
        }
    }

    mutating func saveDuty(id: UUID?, period: Period, kind: TaskKind, text: String, now: Date) {
        let start = period.start(now)
        let end = kind == .temporary ? Period.calendar.date(byAdding: period.component, value: 1, to: start) : nil
        let revision = TaskRevision(text: text, kind: kind, start: start, end: end)
        if let index = duties.firstIndex(where: { $0.id == id }) {
            duties[index].replace(from: start, with: revision)
        } else {
            duties.append(Duty(period: period, revisions: [revision]))
        }
    }

    mutating func removeDuty(_ id: UUID, effective start: Date) {
        guard let index = duties.firstIndex(where: { $0.id == id }) else { return }
        duties[index].replace(from: start, with: nil)
        if duties[index].revisions.isEmpty { duties.remove(at: index) }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> Store {
        struct Header: Decodable { var format: String; var version: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data),
              header.format == formatID else { throw StorageError.invalidBackup }
        guard header.version == 1 else { throw StorageError.unsupportedVersion }
        guard let store = try? decoder.decode(Store.self, from: data),
              Set(store.duties.map(\.id)).count == store.duties.count,
              Set(store.notes.map(\.id)).count == store.notes.count,
              store.duties.allSatisfy({ $0.hasValidHistory }),
              store.notes.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.updatedAt >= $0.createdAt
                  && ($0.kind == .idea) == ($0.priority != nil) })
        else { throw StorageError.invalidBackup }
        return store
    }
}

extension Duty {
    fileprivate var hasValidHistory: Bool {
        guard !revisions.isEmpty, Set(revisions.map(\.id)).count == revisions.count else { return false }
        for (index, revision) in revisions.enumerated() {
            guard !revision.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  revision.start == period.start(revision.start) else { return false }
            if let end = revision.end {
                guard end > revision.start, end == period.start(end) else { return false }
            }
            if revision.kind == .temporary,
               revision.end != Period.calendar.date(byAdding: period.component, value: 1, to: revision.start) {
                return false
            }
            if index > 0 {
                guard let previousEnd = revisions[index - 1].end, previousEnd <= revision.start else { return false }
            }
        }
        return true
    }
}
