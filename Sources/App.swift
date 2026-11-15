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
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.40, dampingFraction: 0.90)))
    private var dragX: CGFloat = 0
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
    private var pageAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.40, dampingFraction: 0.90)
    }

    private var entryAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.32) }

    private var panelTransition: AnyTransition {
        reduceMotion ? .identity : .offset(y: 16).combined(with: .opacity)
    }

    var body: some View {
        VStack(spacing: 0) {
            if expanded {
                VStack(spacing: 0) {
                    detailsHeader
                    details
                }
                .transition(panelTransition)
            } else {
                overview.transition(reduceMotion ? .identity : .opacity)
            }
            if segment != .title { navigation }
        }
        .background(SpacePalette.background.ignoresSafeArea())
        .tint(SpacePalette.accent)
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
            EntryEditor(draft: draft, accent: SpacePalette.tint(for: segment), save: save)
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
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                ForEach(Segment.allCases) { page in
                    let distance = CGFloat(page.rawValue - segment.rawValue)
                    let offset = reduceMotion ? 0 : distance * width + dragX
                    let visibility = max(0, 1 - abs((offset / max(1, width))) * 0.75)
                    heading(page)
                        .frame(width: width, height: geometry.size.height)
                        .offset(x: offset)
                        .opacity(reduceMotion ? (distance == 0 ? 1 : 0) : visibility)
                        .accessibilityHidden(distance != 0)
                        .allowsHitTesting(distance == 0)
                }
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(pageGesture(size: geometry.size, expanded: false))
        }
    }

    @ViewBuilder private func heading(_ page: Segment) -> some View {
        if page == .title {
            Button { go(to: .daily) } label: {
                Text(page.name)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .foregroundStyle(SpacePalette.ink)
                    .multilineTextAlignment(.center)
                    .padding(24)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Otwiera segment Codzienne")
        } else {
            VStack(spacing: 12) {
                Text(page.name)
                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .foregroundStyle(SpacePalette.ink)
                if page == .daily || page == .weekly {
                    Text((page == .daily ? Period.daily : .weekly).label(now))
                        .font(.subheadline)
                        .foregroundStyle(SpacePalette.muted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 38)
            .frame(maxWidth: 360)
            .background(SpacePalette.tint(for: page), in: RoundedRectangle(cornerRadius: 32))
            .padding(.horizontal, 24)
        }
    }

    private var detailsHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(segment.name)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(SpacePalette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let period {
                    Text(period.label(now)).font(.footnote).foregroundStyle(SpacePalette.muted)
                }
            }
            .id(segment)
            .transition(reduceMotion ? .identity : .opacity)
            Spacer(minLength: 0)
            if segment != .archive {
                Button {
                    now = Date()
                    if let period { editor = .newDuty(period) }
                    if let noteKind { editor = .newNote(noteKind, title: segment.name) }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(SpaceButtonStyle(fill: SpacePalette.tint(for: segment)))
                .accessibilityLabel("Dodaj wpis")
                .disabled(!data.isAvailable)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .gesture(pageGesture(size: .zero, expanded: true))
    }

    @ViewBuilder private var details: some View {
        if let period {
            List {
                ForEach(TaskKind.allCases) { kind in
                    Section {
                        let tasks = data.store.tasks(period, kind, at: now)
                        if tasks.isEmpty { EmptyCard(title: "Brak zadań") }
                        ForEach(tasks.map { $0.0 }) { duty in
                            if let entry = duty.revision(at: period.start(now)) {
                                row(entry.text, edit: { editor = .editDuty(duty, entry, now: now) },
                                    delete: .duty(duty.id, period.start(now)))
                            }
                        }
                    } header: {
                        Text(kind.label(period)).spaceSectionTitle()
                    }
                }
            }
            .spaceList()
            .id(period)
            .transition(reduceMotion ? .identity : .opacity)
        } else if let noteKind {
            let notes = data.store.notes(of: noteKind)
            List {
                if notes.isEmpty {
                    EmptyCard(title: "Brak wpisów", detail: "Stuknij +, aby dodać pierwszy wpis.")
                }
                ForEach(notes) { note in
                    let index = noteKind == .commandment ? notes.firstIndex { $0.id == note.id } : nil
                    let date = Period.dateLabel(note.createdAt, format: "d MMM yyyy, HH:mm")
                    row(note.text, number: index.map { $0 + 1 },
                        subtitle: noteKind == .commandment ? nil : date,
                        priority: note.priority,
                        edit: { editor = .editNote(note, title: segment.name) }, delete: .note(note.id))
                }
            }
            .spaceList()
            .id(noteKind)
            .transition(reduceMotion ? .identity : .opacity)
        } else {
            ArchiveView(store: data.store, now: now, export: exportBackup, restore: { importing = true })
                .transition(reduceMotion ? .identity : .opacity)
        }
    }

    private func row(
        _ text: String, number: Int? = nil, subtitle: String? = nil, priority: Priority? = nil,
        edit: @escaping () -> Void, delete: Deletion
    ) -> some View {
        Button(action: edit) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let number {
                    Text("\(number).").font(.subheadline.weight(.semibold)).foregroundStyle(SpacePalette.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(SpacePalette.ink)
                        .multilineTextAlignment(.leading)
                        .id(text)
                        .transition(reduceMotion ? .identity : .opacity)
                    if let priority {
                        Text(priority.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SpacePalette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(priorityTint(priority), in: Capsule())
                            .accessibilityLabel("Priorytet: \(priority.rawValue)")
                    }
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(SpacePalette.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .spaceCard()
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { pendingDelete = delete } label: { Label("Usuń", systemImage: "trash") }
                .tint(SpacePalette.destructive)
        }
        .accessibilityAction(named: Text("Usuń")) { pendingDelete = delete }
        .contextMenu { Button("Usuń", role: .destructive) { pendingDelete = delete } }
        .spaceListRow()
    }

    private func priorityTint(_ priority: Priority) -> Color {
        switch priority {
        case .low: SpacePalette.sage
        case .medium: SpacePalette.lavender
        case .high: SpacePalette.peach
        }
    }

    private var navigation: some View {
        HStack(spacing: 8) {
            navButton("chevron.left", "Poprzedni segment") { move(-1) }
            Spacer(minLength: 0)
            Button { setExpanded(!expanded) } label: {
                Label(expanded ? "Zwiń" : "Otwórz", systemImage: expanded ? "chevron.down" : "chevron.up")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
            }
            .buttonStyle(SpaceButtonStyle(fill: SpacePalette.tint(for: segment)))
            Spacer(minLength: 0)
            navButton("chevron.right", "Następny segment") { move(1) }
                .disabled(segment == .archive)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(pageGesture(size: .zero, expanded: expanded))
    }

    private func navButton(_ icon: String, _ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).frame(width: 44, height: 44) }
            .buttonStyle(SpaceButtonStyle())
            .accessibilityLabel(name)
    }

    private func pageGesture(size: CGSize, expanded isExpanded: Bool) -> some Gesture {
        DragGesture(minimumDistance: 18)
            .updating($dragX) { value, offset, transaction in
                let x = value.translation.width
                let y = value.translation.height
                guard size.width > 0, !isExpanded, segment != .title, !reduceMotion,
                      abs(x) > abs(y) else { return }
                transaction.animation = nil
                let atEnd = segment == .archive && x < 0
                offset = min(size.width, max(-size.width, x)) * (atEnd ? 0.18 : 1)
            }
            .onEnded { value in
                let x = value.translation.width
                let y = value.translation.height
                if segment == .title {
                    let start = value.startLocation
                    if abs(start.x - size.width / 2) < size.width * 0.30,
                       abs(start.y - size.height / 2) < size.height * 0.24,
                       y > max(48, abs(x)) {
                        go(to: .daily)
                    }
                } else if abs(x) > abs(y) * 1.2 {
                    let projected = value.predictedEndTranslation.width
                    if abs(x) > 48 || (abs(x) > 26 && abs(projected) > 105) {
                        move(x < 0 ? 1 : -1)
                    }
                } else if isExpanded, y > 45, abs(y) > abs(x) {
                    setExpanded(false)
                } else if !isExpanded, y < -45, abs(y) > abs(x) {
                    setExpanded(true)
                }
            }
    }

    private func move(_ step: Int) {
        if let destination = Segment(rawValue: lastSegment + step) { go(to: destination) }
    }

    private func go(to destination: Segment) {
        now = Date()
        withAnimation(pageAnimation) {
            lastSegment = destination.rawValue
            expanded = expanded && destination != .title
        }
    }

    private func setExpanded(_ value: Bool) {
        now = Date()
        withAnimation(pageAnimation) { expanded = value }
    }

    private func save(_ draft: EditorDraft) -> Bool {
        now = Date()
        switch draft.subject {
        case let .duty(period, originalStart):
            if let originalStart, originalStart != period.start(now) {
                data.errorMessage = "Ten okres się skończył. Otwórz ponownie aktualną listę, aby zmienić zadanie."
                return false
            }
            return withAnimation(entryAnimation) {
                data.update { $0.saveDuty(id: draft.entryID, period: period, kind: draft.taskKind, text: draft.cleanedText, now: now) }
            }
        case .note(let kind):
            let time = now
            return withAnimation(entryAnimation) {
                data.update { store in
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
    }

    private func delete(_ action: Deletion) {
        now = Date()
        withAnimation(entryAnimation) {
            switch action {
            case .duty(let id, let originalStart):
                guard let period, period.start(now) == originalStart else { return }
                data.update { $0.removeDuty(id, effective: originalStart) }
            case .note(let id): data.update { $0.notes.removeAll { $0.id == id } }
            }
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
