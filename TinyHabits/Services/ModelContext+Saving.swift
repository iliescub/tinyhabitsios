import SwiftData

extension ModelContext {
    func saveIfNeeded(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            assertionFailure("ModelContext save failed (\(file):\(line)): \(error)")
        }
    }
}

