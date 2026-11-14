import Combine
import Foundation

@MainActor
final class LocalData: ObservableObject {
    @Published private(set) var store = Store()
    @Published var errorMessage: String?
    @Published private(set) var isAvailable = false
    private var location: URL?

    init() {
        do {
            let folder = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            )
            let url = folder.appendingPathComponent("store.json")
            location = url
            do {
                store = try Store.decode(Data(contentsOf: url))
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                store = Store()
            }
            isAvailable = true
        } catch {
            errorMessage = "Nie udało się odczytać danych lokalnych. Zapis został wstrzymany. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func update(_ mutation: (inout Store) -> Void) -> Bool {
        var next = store
        mutation(&next)
        return replace(with: next)
    }

    func replace(with next: Store) -> Bool {
        do {
            guard isAvailable, let location else { throw StorageError.unavailable }
            try next.encoded().write(to: location, options: [.atomic, .completeFileProtection])
            store = next
            return true
        } catch {
            errorMessage = "Nie udało się zapisać danych. \(error.localizedDescription)"
            return false
        }
    }
}
