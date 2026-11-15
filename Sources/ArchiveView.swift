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
                Section {
                    ForEach(Period.allCases) { period in
                        archiveLink(period.archiveLabel, to: .years(period))
                    }
                } header: {
                    Text("Historia").spaceSectionTitle()
                }
                Section {
                    archiveButton("Eksportuj kopię JSON", icon: "square.and.arrow.up", action: export)
                    archiveButton("Odtwórz kopię z Plików", icon: "square.and.arrow.down", action: restore)
                } header: {
                    Text("Kopia zapasowa").spaceSectionTitle()
                }
            }
            .spaceList()
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .years(let period):
                    List(years(period), id: \.self) { year in
                        archiveLink(String(year), to: .year(period, year))
                    }.spaceList().navigationTitle(period.archiveLabel)
                case .year(.daily, let year):
                    List(months(year), id: \.self) { month in
                        archiveLink(Period.dateLabel(date(year, month), format: "LLLL").capitalized,
                                    to: .month(year, month))
                    }.spaceList().navigationTitle(String(year))
                case .year(.weekly, let year):
                    List(weeks(year), id: \.self) { week in
                        archiveLink(Period.weekly.label(week), to: .entries(.weekly, week))
                    }.spaceList().navigationTitle(String(year))
                case .month(let year, let month):
                    List(days(year, month), id: \.self) { day in
                        archiveLink(Period.daily.label(day), to: .entries(.daily, day))
                    }.spaceList().navigationTitle(Period.dateLabel(date(year, month), format: "LLLL yyyy").capitalized)
                case .entries(let period, let day):
                    List {
                        ForEach(TaskKind.allCases) { kind in
                            Section {
                                let tasks = store.tasks(period, kind, at: day)
                                if tasks.isEmpty { EmptyCard(title: "Brak wpisów") }
                                ForEach(tasks.map { $0.1 }) { entry in
                                    Text(entry.text)
                                        .foregroundStyle(SpacePalette.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .spaceCard()
                                        .spaceListRow()
                                }
                            } header: {
                                Text(kind.label(period)).spaceSectionTitle()
                            }
                        }
                    }.spaceList().navigationTitle(period.label(day))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SpacePalette.background, for: .navigationBar)
        }
    }

    private func archiveLink(_ title: String, to page: Page) -> some View {
        NavigationLink(value: page) {
            Text(title).foregroundStyle(SpacePalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
                .padding(.leading, 16)
        }
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 20)
                .fill(SpacePalette.surface)
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(SpacePalette.border) }
                .padding(.horizontal, 20)
        )
    }

    private func archiveButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .buttonStyle(SpaceButtonStyle(fill: SpacePalette.sage))
        .spaceListRow()
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
