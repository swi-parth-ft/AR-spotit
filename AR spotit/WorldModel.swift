import Foundation

struct WorldModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let filePath: URL

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.filePath = WorldModel.appSupportDirectory.appendingPathComponent("\(name)_worldMap")
    }

    static var appSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportPath = paths.first!
        if !FileManager.default.fileExists(atPath: appSupportPath.path) {
            do {
                try FileManager.default.createDirectory(at: appSupportPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Unable to create Application Support directory: \(error.localizedDescription)")
            }
        }
        return appSupportPath
    }
}
