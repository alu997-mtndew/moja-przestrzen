import Foundation

func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    Period.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

func check(_ test: Bool, _ description: String) {
    guard test else { fatalError(description) }
}

var store = Store()
let sunday = date(2026, 3, 29)
let monday = date(2026, 3, 30)
let tuesday = date(2026, 3, 31)
let sundayStart = Period.daily.start(sunday)
let mondayStart = Period.daily.start(monday)

check(mondayStart.timeIntervalSince(sundayStart) == 23 * 3600, "Zmiana czasu na letni")
check(Period.daily.start(date(2026, 10, 26)).timeIntervalSince(Period.daily.start(date(2026, 10, 25))) == 25 * 3600, "Zmiana czasu na zimowy")
check(Period.weekly.start(sunday) == Period.daily.start(date(2026, 3, 23)), "Tydzień zaczyna się w poniedziałek")
check(Period.weekly.year(date(2018, 12, 31)) == 2019, "Grudniowy dzień w kolejnym roku ISO")
check(Period.weekly.year(date(2021, 1, 1)) == 2020, "Styczniowy dzień w poprzednim roku ISO")

store.saveDuty(id: nil, period: .daily, kind: .recurring, text: "Stary wpis", now: sunday)
let recurring = store.duties[0].id
store.saveDuty(id: nil, period: .daily, kind: .temporary, text: "Tylko w niedzielę", now: sunday)
store.saveDuty(id: nil, period: .weekly, kind: .temporary, text: "Tylko w tym tygodniu", now: sunday)
check(store.tasks(.weekly, .temporary, at: sunday).count == 1, "Bieżący wpis tygodniowy")
check(store.tasks(.weekly, .temporary, at: monday).isEmpty, "Tydzień wygasa w poniedziałek")
check(store.tasks(.daily, .temporary, at: monday).isEmpty, "Dzień wygasa o północy")
check(store.tasks(.daily, .recurring, at: monday).count == 1, "Stały wpis przechodzi na kolejny dzień")
store.saveDuty(id: recurring, period: .daily, kind: .recurring, text: "Nowy wpis", now: monday)
check(store.tasks(.daily, .recurring, at: sunday).first?.1.text == "Stary wpis", "Archiwum zachowuje poprzednią wersję")
store.removeDuty(recurring, effective: Period.daily.start(tuesday))
check(store.tasks(.daily, .recurring, at: monday).first?.1.text == "Nowy wpis", "Usunięcie zabezpiecza zamkniętą historię")
check(store.tasks(.daily, .recurring, at: tuesday).isEmpty, "Usunięcie wycofuje stały wpis")

let first = Note(kind: .idea, text: "Pierwsza", createdAt: sunday, updatedAt: tuesday, priority: .high)
let second = Note(kind: .idea, text: "Druga", createdAt: monday, updatedAt: monday, priority: .low)
store.notes = [first, second]
check(store.notes(of: .idea).map(\.id) == [second.id, first.id], "Chronologia zależy od daty dodania")
let bytes = try store.encoded()
let restored = try Store.decode(bytes)
check(try restored.encoded() == bytes, "Pełne odtworzenie danych")
var invalid = store
invalid.notes.append(first)
check((try? Store.decode(try invalid.encoded())) == nil, "Odrzucenie powtórzonego identyfikatora")
invalid.version = 2
do {
    _ = try Store.decode(invalid.encoded())
    fatalError("Odrzucenie przyszłej wersji kopii")
} catch StorageError.unsupportedVersion {
    print("OK: granice dni i tygodni, historia, sortowanie i kopia JSON")
}
