import SwiftUI

struct ArchiveView: View {
    let store: Store
    let now: Date
    let export: () -> Void
    let restore: () -> Void

    private enum Page: Hashable {
        case years(Period), year(Period, Int), month(Int, Int), entries(Period, Date)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Historia") {
                    ForEach(Period.allCases) { period in
                        NavigationLink(period.archiveLabel, value: Page.years(period))
                    }
                }
                Section("Kopia zapasowa") {
                    Button("Eksportuj kopię JSON", action: export)
                    Button("Odtwórz kopię z Plików", action: restore)
                }
            }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .years(let period):
                    List(years(period), id: \.self) { year in
                        NavigationLink(String(year), value: Page.year(period, year))
                    }.navigationTitle(period.archiveLabel)
                case .year(.daily, let year):
                    List(months(year), id: \.self) { month in
                        NavigationLink(Period.dateLabel(date(year, month), format: "LLLL").capitalized,
                                       value: Page.month(year, month))
                    }.navigationTitle(String(year))
                case .year(.weekly, let year):
                    List(weeks(year), id: \.self) { week in
                        NavigationLink(Period.weekly.label(week), value: Page.entries(.weekly, week))
                    }.navigationTitle(String(year))
                case .month(let year, let month):
                    List(days(year, month), id: \.self) { day in
                        NavigationLink(Period.daily.label(day), value: Page.entries(.daily, day))
                    }.navigationTitle(Period.dateLabel(date(year, month), format: "LLLL yyyy").capitalized)
                case .entries(let period, let day):
                    List {
                        ForEach(TaskKind.allCases) { kind in
                            Section(kind.label(period)) {
                                let tasks = store.tasks(period, kind, at: day)
                                if tasks.isEmpty { Text("Brak wpisów").foregroundStyle(.secondary) }
                                ForEach(tasks.map { $0.1 }) { entry in Text(entry.text) }
                            }
                        }
                    }.navigationTitle(period.label(day))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .listStyle(.insetGrouped)
    }

    private func years(_ period: Period) -> [Int] {
        let lastYear = period.year(now)
        let earliest = store.duties.filter { $0.period == period }
            .compactMap { $0.revisions.first?.start }.min() ?? now
        return Array((min(period.year(earliest), lastYear)...lastYear).reversed())
    }

    private func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
        Period.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func months(_ year: Int) -> [Int] {
        (1...12).reversed().filter { date(year, $0) < Period.daily.start(now) }
    }

    private func days(_ year: Int, _ month: Int) -> [Date] {
        let range = Period.calendar.range(of: .day, in: .month, for: date(year, month))!
        return range.reversed().map { date(year, month, $0) }.filter { $0 < Period.daily.start(now) }
    }

    private func weeks(_ year: Int) -> [Date] {
        let januaryFourth = date(year, 1, 4)
        let first = Period.weekly.start(januaryFourth)
        return (0..<53).compactMap {
            Period.calendar.date(byAdding: .weekOfYear, value: $0, to: first)
        }.filter { Period.weekly.year($0) == year && $0 < Period.weekly.start(now) }.reversed()
    }
}
