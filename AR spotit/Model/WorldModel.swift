import Foundation

struct WorldModel: Identifiable, Codable {
    let id: UUID
    var name: String
    var lastModified: Date // Timestamp to track the last modification

    // Computed property for dynamic file path
    var filePath: URL {
        let fileName: String
        if self.name.hasSuffix("_worldMap") {
            fileName = self.name
        } else {
            fileName = "\(self.name)_worldMap"
        }
        return WorldModel.appSupportDirectory.appendingPathComponent(fileName)
    }

    init(name: String, lastModified: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.lastModified = lastModified
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
