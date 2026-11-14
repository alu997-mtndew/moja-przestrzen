import SwiftUI
import UniformTypeIdentifiers
import UIKit

@main
struct MojaPrzestrzenApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

struct HomeView: View {
    @StateObject private var data = LocalData()
    @AppStorage("lastSegment") private var lastSegment = Segment.title.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var expanded = false
    @State private var dragX: CGFloat = 0
    @State private var now = Date()
    @State private var editor: EditorDraft?
    @State private var pendingDelete: Deletion?
    @State private var backup: BackupFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingImport: Store?

    private var segment: Segment { Segment(rawValue: lastSegment) ?? .title }
    private var period: Period? {
        switch segment {
        case .daily: .daily
        case .weekly: .weekly
        default: nil
        }
    }
    private var noteKind: NoteKind? {
        switch segment {
        case .problems: .problem
        case .behavior: .behavior
        case .commandments: .commandment
        case .ideas: .idea
        default: nil
        }
    }
    private var animation: Animation? { reduceMotion ? nil : .easeOut(duration: 0.24) }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                detailsHeader
                details
            } else {
                overview
            }
            if segment != .title { navigation }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear { now = Date() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { now = Date() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in now = Date() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in now = Date() }
        .task {
            while !Task.isCancelled {
                do {
                    let boundary = Period.calendar.dateInterval(of: .day, for: Date())!.end
                    try await Task.sleep(for: .seconds(max(0.2, boundary.timeIntervalSinceNow)))
                    now = Date()
                } catch { return }
            }
        }
        .sheet(item: $editor) { draft in
            EntryEditor(draft: draft, save: save)
        }
        .confirmationDialog("Usunąć ten wpis?", isPresented: showingDelete, titleVisibility: .visible) {
            Button("Usuń", role: .destructive) {
                if let pendingDelete { delete(pendingDelete) }
                pendingDelete = nil
            }
            Button("Anuluj", role: .cancel) { pendingDelete = nil }
        }
        .confirmationDialog("Odtworzyć kopię?", isPresented: showingImport, titleVisibility: .visible) {
            Button("Zastąp dane kopią", role: .destructive) {
                if let pendingImport { _ = data.replace(with: pendingImport) }
                pendingImport = nil
            }
            Button("Anuluj", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Kopia zastąpi wszystkie obecne wpisy i archiwum. Przed odtworzeniem możesz wyeksportować obecne dane.")
        }
        .fileExporter(isPresented: $exporting, document: backup, contentType: .json,
                      defaultFilename: "MojaPrzestrzen-\(Period.dateLabel(Date(), format: "yyyy-MM-dd")).json") { result in
            backup = nil
            if case .failure(let error) = result { data.errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], onCompletion: readBackup)
        .alert("Moja przestrzeń", isPresented: Binding(
            get: { data.errorMessage != nil },
            set: { if !$0 { data.errorMessage = nil } }
        )) {
            Button("OK") { data.errorMessage = nil }
        } message: { Text(data.errorMessage ?? "") }
    }

    private var showingDelete: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var showingImport: Binding<Bool> {
        Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })
    }

    private var overview: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                if segment == .title {
                    heading(.title)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { go(to: .daily) }
                        .onTapGesture { go(to: .daily) }
                } else {
                    ForEach(Segment.allCases) { page in
                        let distance = page.rawValue - lastSegment
                        if abs(distance) <= 1 {
                            heading(page)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .offset(x: CGFloat(distance) * geo.size.width + dragX)
                                .accessibilityHidden(distance != 0)
                                .allowsHitTesting(distance == 0)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(pageGesture(size: geo.size, expanded: false))
        }
    }

    private func heading(_ page: Segment) -> some View {
        VStack(spacing: 12) {
            Text(page.name)
                .font(.largeTitle.weight(.medium))
                .accessibilityAddTraits(.isHeader)
            if page == .daily || page == .weekly {
                Text((page == .daily ? Period.daily : .weekly).label(now))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private var detailsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(segment.name).font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if segment != .archive {
                Button {
                    now = Date()
                    if let period { editor = .newDuty(period) }
                    if let noteKind { editor = .newNote(noteKind, title: segment.name) }
                } label: {
                    Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Dodaj wpis")
                .disabled(!data.isAvailable)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(pageGesture(size: .zero, expanded: true))
    }

    @ViewBuilder private var details: some View {
        if let period {
            List {
                ForEach(TaskKind.allCases) { kind in
                    Section(kind.label(period)) {
                        let tasks = data.store.tasks(period, kind, at: now)
                        if tasks.isEmpty { Text("Brak wpisów").foregroundStyle(.secondary) }
                        ForEach(tasks.map { $0.0 }) { duty in
                            if let entry = duty.revision(at: period.start(now)) {
                                row(entry.text, edit: { editor = .editDuty(duty, entry, now: now) },
                                    delete: .duty(duty.id, period.start(now)))
                            }
                        }
                    }
                }
            }.listStyle(.insetGrouped)
        } else if let noteKind {
            let notes = data.store.notes(of: noteKind)
            List {
                if notes.isEmpty { Text("Brak wpisów").foregroundStyle(.secondary) }
                ForEach(notes) { note in
                    let index = notes.firstIndex { $0.id == note.id } ?? 0
                    let text = noteKind == .commandment ? "\(index + 1). \(note.text)" : note.text
                    let date = Period.dateLabel(note.createdAt, format: "d MMM yyyy, HH:mm")
                    row(text, subtitle: [note.priority?.rawValue, noteKind == .commandment ? nil : date]
                        .compactMap { $0 }.joined(separator: " · "),
                        edit: { editor = .editNote(note, title: segment.name) }, delete: .note(note.id))
                }
            }.listStyle(.insetGrouped)
        } else {
            ArchiveView(store: data.store, now: now, export: exportBackup, restore: { importing = true })
                .id(segment)
        }
    }

    private func row(_ text: String, subtitle: String = "", edit: @escaping () -> Void, delete: Deletion) -> some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 5) {
                Text(text).foregroundStyle(.primary).multilineTextAlignment(.leading)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { pendingDelete = delete } label: { Label("Usuń", systemImage: "trash") }
                .tint(.red)
        }
        .accessibilityAction(named: Text("Usuń")) { pendingDelete = delete }
        .contextMenu { Button("Usuń", role: .destructive) { pendingDelete = delete } }
    }

    private var navigation: some View {
        HStack {
            navButton("chevron.left", "Poprzedni segment") { move(-1) }
            Spacer()
            Button { setExpanded(!expanded) } label: {
                Label(expanded ? "Zwiń" : "Otwórz", systemImage: expanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            Spacer()
            navButton("chevron.right", "Następny segment") { move(1) }
                .disabled(segment == .archive)
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .gesture(pageGesture(size: .zero, expanded: expanded))
    }

    private func navButton(_ icon: String, _ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 44, height: 44) }
            .accessibilityLabel(name)
    }

    private func pageGesture(size: CGSize, expanded isExpanded: Bool) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let x = value.translation.width
                let y = value.translation.height
                guard !isExpanded, segment != .title, !reduceMotion, abs(x) > abs(y) else {
                    dragX = 0
                    return
                }
                dragX = min(size.width, max(-size.width, x))
                if segment == .archive, x < 0 { dragX *= 0.2 }
            }
            .onEnded { value in
                let x = value.translation.width
                let y = value.translation.height
                withAnimation(animation) { dragX = 0 }
                if segment == .title {
                    let start = value.startLocation
                    if abs(start.x - size.width / 2) < size.width * 0.30,
                       abs(start.y - size.height / 2) < size.height * 0.24,
                       y > max(48, abs(x)) {
                        go(to: .daily)
                    }
                } else if abs(x) > max(42, abs(y) * 1.2) {
                    move(x < 0 ? 1 : -1)
                } else if isExpanded, y < -45, abs(y) > abs(x) {
                    setExpanded(false)
                } else if !isExpanded, y > 45, abs(y) > abs(x) {
                    setExpanded(true)
                }
            }
    }

    private func move(_ step: Int) {
        if let destination = Segment(rawValue: lastSegment + step) { go(to: destination) }
    }

    private func go(to destination: Segment) {
        now = Date()
        withAnimation(animation) {
            lastSegment = destination.rawValue
            dragX = 0
            expanded = expanded && destination != .title
        }
    }

    private func setExpanded(_ value: Bool) {
        now = Date()
        withAnimation(animation) { expanded = value }
    }

    private func save(_ draft: EditorDraft) -> Bool {
        now = Date()
        switch draft.subject {
        case let .duty(period, originalStart):
            if let originalStart, originalStart != period.start(now) {
                data.errorMessage = "Ten okres się skończył. Otwórz ponownie aktualną listę, aby zmienić zadanie."
                return false
            }
            return data.update { $0.saveDuty(id: draft.entryID, period: period, kind: draft.taskKind, text: draft.cleanedText, now: now) }
        case .note(let kind):
            let time = now
            return data.update { store in
                let priority = kind == .idea ? draft.priority : nil
                if let index = store.notes.firstIndex(where: { $0.id == draft.entryID }) {
                    store.notes[index].text = draft.cleanedText
                    store.notes[index].updatedAt = max(time, store.notes[index].createdAt)
                    store.notes[index].priority = priority
                    store.notes[index].reflections = draft.reflections.isEmpty ? nil : draft.reflections
                } else {
                    store.notes.append(Note(kind: kind, text: draft.cleanedText, createdAt: time, updatedAt: time, priority: priority))
                }
            }
        }
    }

    private func delete(_ action: Deletion) {
        now = Date()
        switch action {
        case .duty(let id, let originalStart):
            guard let period, period.start(now) == originalStart else { return }
            data.update { $0.removeDuty(id, effective: originalStart) }
        case .note(let id): data.update { $0.notes.removeAll { $0.id == id } }
        }
    }

    private func exportBackup() {
        guard data.isAvailable else { data.errorMessage = StorageError.unavailable.localizedDescription; return }
        do {
            backup = BackupFile(bytes: try data.store.encoded())
            exporting = true
        } catch { data.errorMessage = error.localizedDescription }
    }

    private func readBackup(_ result: Result<URL, Error>) {
        do {
            guard data.isAvailable else { throw StorageError.unavailable }
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try Store.decode(Data(contentsOf: url))
        } catch { data.errorMessage = error.localizedDescription }
    }
}

private enum Deletion {
    case duty(UUID, Date)
    case note(UUID)
}

private struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let bytes: Data

    init(bytes: Data) { self.bytes = bytes }

    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else { throw StorageError.invalidBackup }
        self.bytes = bytes
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: bytes)
    }
}
