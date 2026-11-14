import SwiftUI

struct EditorDraft: Identifiable {
    enum Subject {
        case duty(Period, originalStart: Date?)
        case note(NoteKind)
    }

    let id = UUID()
    let entryID: UUID?
    let title: String
    let subject: Subject
    var text = ""
    var taskKind = TaskKind.recurring
    var priority = Priority.medium
    var reflections: [Reflection] = []

    var cleanedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    static func newDuty(_ period: Period) -> Self {
        Self(entryID: nil, title: "Nowe zadanie", subject: .duty(period, originalStart: nil))
    }

    static func editDuty(_ duty: Duty, _ revision: TaskRevision, now: Date) -> Self {
        Self(entryID: duty.id, title: "Edytuj zadanie", subject: .duty(duty.period, originalStart: duty.period.start(now)),
             text: revision.text, taskKind: revision.kind)
    }

    static func newNote(_ kind: NoteKind, title: String) -> Self {
        Self(entryID: nil, title: title, subject: .note(kind))
    }

    static func editNote(_ note: Note, title: String) -> Self {
        Self(entryID: note.id, title: title, subject: .note(note.kind), text: note.text,
             priority: note.priority ?? .medium, reflections: note.reflections ?? [])
    }
}

struct EntryEditor: View {
    @State var draft: EditorDraft
    let save: (EditorDraft) -> Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @State private var reflectionText = ""

    private enum Field { case body, reflection }
    private var cleanedReflection: String { reflectionText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Treść", text: $draft.text, axis: .vertical)
                        .lineLimit(4...12)
                        .focused($focus, equals: .body)
                    switch draft.subject {
                    case .duty(let period, _):
                        Picker("Sekcja", selection: $draft.taskKind) {
                            ForEach(TaskKind.allCases) { Text($0.label(period)).tag($0) }
                        }.pickerStyle(.segmented)
                    case .note(.idea):
                        Picker("Priorytet", selection: $draft.priority) {
                            ForEach(Priority.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                    default:
                        EmptyView()
                    }
                }
                if case .note(.behavior) = draft.subject, draft.entryID != nil {
                    Section("Refleksje") {
                        ForEach(draft.reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.text)
                                Text(Period.dateLabel(reflection.createdAt, format: "d MMM yyyy, HH:mm"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        TextField("Dopisz refleksję", text: $reflectionText, axis: .vertical)
                            .focused($focus, equals: .reflection)
                    }
                }
            }
            .navigationTitle(draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        var next = draft
                        if !cleanedReflection.isEmpty {
                            next.reflections.append(Reflection(text: cleanedReflection, createdAt: Date()))
                        }
                        if save(next) { dismiss() }
                    }.disabled(draft.cleanedText.isEmpty)
                }
            }
            .task { if draft.entryID == nil { focus = .body } }
        }
    }
}
