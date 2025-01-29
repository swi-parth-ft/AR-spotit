//
//  OpenWorldIntent.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-26.
//
import AppIntents
import CoreSpotlight
import MobileCoreServices

/// This requires iOS 16.4 or newer
@available(iOS 16.4, *)
struct OpenWorldIntent: ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Search Area"
    
    
    @Parameter(
        title: "World",
        optionsProvider: WorldOptionsProvider() // Add this
    ) var worldName: WorldEntity

    /// Returning 'some IntentResult & ProvidesDialog' so we can show a success message.
    @MainActor
    func perform() async throws -> some IntentResult {


        try await requestToContinueInForeground("Ready to open \(worldName.name) in it's here.?")

        
        NotificationCenter.default.post(
            name: Notification.Name("OpenWorldNotification"),
            object: nil,
            userInfo: ["worldName": worldName.name]
        )
        
        return .result()
    }
}




@available(iOS 16.4, *)
struct CreateWorldIntent: ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Create Area"

    @Parameter(title: "Area Name")
    var worldName: String

    /// Returning 'some IntentResult & ProvidesDialog' so we can show a success message.
    @MainActor
    func perform() async throws -> some IntentResult {
        

        try await requestToContinueInForeground("Ready to create \(worldName) in it's here.?")

        
        NotificationCenter.default.post(
            name: Notification.Name("CreateWorldNotification"),
            object: nil,
            userInfo: ["worldName": worldName]
        )
        
        return .result()
    }
}

@available(iOS 16.4, *)
struct OpenItemIntent: ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Search Item"

    @Parameter(title: "Item Name", optionsProvider: AnchorNameOptionsProvider())
    var itemName: String

    /// Returning 'some IntentResult & ProvidesDialog' so we can show a success message.
    @MainActor
    func perform() async throws -> some IntentResult {
        

        try await requestToContinueInForeground("Ready to search for \(itemName) in it's here.?")

        
        NotificationCenter.default.post(
            name: Notification.Name("FindItemNotification"),
            object: nil,
            userInfo: ["itemName": itemName]
        )
        
        return .result()
    }
}



struct OpenWorldShortcut: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange
    
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        
        AppShortcut(
            intent: OpenWorldIntent(),
            phrases: [
                "Search World in \(.applicationName)",
                "Open Area in \(.applicationName)",
                "Search Area in \(.applicationName)",
                "Explore in \(.applicationName)",
                "Start World in \(.applicationName)",
                "Launch \(.applicationName) World",
                "Unlock World in \(.applicationName)",
                "Begin Search in \(.applicationName)",
                "Search in \(.applicationName)",
                "Open Area \(\.$worldName) in \(.applicationName)",
                "Launch \(\.$worldName) in \(.applicationName)",
                "View \(\.$worldName) in AR with \(.applicationName)",
                "Browse \(\.$worldName) with \(.applicationName)"
            ],
            shortTitle: "Search Area",
            systemImageName: "arkit"
        )
        
        AppShortcut(
            intent: CreateWorldIntent(),
            phrases: [
                "Create a new world in \(.applicationName)",
                "Add a new area in \(.applicationName)",
                "Start a new area in \(.applicationName)",
                "Generate a world in \(.applicationName)",
                "Build a world in \(.applicationName)",
                "Design a world in \(.applicationName)",
                "New world creation in \(.applicationName)",
                "Open a new area in \(.applicationName)",
                "Launch a new world in \(.applicationName)",
                "Create area in \(.applicationName)"
            ],
            shortTitle: "Create Area",
            systemImageName: "plus.circle"
        )
        
        AppShortcut(
            intent: OpenItemIntent(),
            phrases: [
                "Look for item in \(.applicationName)",
                "search for item in \(.applicationName)",
                "Find an item in \(.applicationName)",
                "Search item in \(.applicationName)",
                "Discover an item in \(.applicationName)",
                "Find item in \(.applicationName)",
                "Search item in \(.applicationName)"
            ],
            shortTitle: "Seach Item",
            systemImageName: "magnifyingglass.circle"
        )
        
    }
}


struct WorldNameOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        // Wait for the saved worlds to load
        try await withCheckedThrowingContinuation { continuation in
            WorldManager.shared.loadSavedWorlds {
                let worlds = WorldManager.shared.savedWorlds.map { $0.name }
                print(worlds) // Ensure worlds are printed correctly
                continuation.resume(returning: worlds)
            }
        }
    }
}

struct WorldOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [WorldEntity] {
        try await WorldEntity.WorldQuery().suggestedEntities()
    }
}


struct AnchorNameOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            WorldManager.shared.loadSavedWorlds {
                Task {
                    var items: [String] = []
                    
                    await withTaskGroup(of: [String].self) { group in
                        for world in WorldManager.shared.savedWorlds {
                            group.addTask {
                                await withCheckedContinuation { innerContinuation in
                                    WorldManager.shared.getAnchorNames(for: world.name) { fetchedAnchors in
                                        let filteredAnchors = fetchedAnchors.filter { $0.lowercased() != "guide" }
                                        innerContinuation.resume(returning: filteredAnchors)                                    }
                                }
                            }
                        }
                        
                        // Collect results from all tasks
                        for await fetchedAnchors in group {
                            items.append(contentsOf: fetchedAnchors)
                        }
                    }
                    
                    continuation.resume(returning: items)
                }
            }
        }
    }
}


@available(iOS 16.0, *)
struct WorldEntity: AppEntity, Identifiable {
    
    static let defaultQuery = WorldQuery()
    
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "World"
    )
    let id: UUID
    
    
    var persistentIdentifier: UUID {
        id
    }
    
    let name: String
    
    var displayRepresentation: DisplayRepresentation {
      //  DisplayRepresentation(title: "\(name)")
       // DisplayRepresentation(title: LocalizedStringResource("%@", defaultValue: String.LocalizationValue(name))) // This works
        DisplayRepresentation(stringLiteral: name)


    }
    
    struct WorldQuery: EntityQuery {
//        
//        func suggestedEntities() async throws -> [WorldEntity] {
////            return [
////                       WorldEntity(id: UUID(), name: "Dark room"),
////                       WorldEntity(id: UUID(), name: "Utility Closet")
//            await loadWorlds()
//        }
//        
//        
//        
//        func entities(for identifiers: [UUID]) async throws -> [WorldEntity] {
//            
//            
//            let savedWorlds = await loadWorlds()
//            return savedWorlds
//                .filter { identifiers.contains($0.id) }
//                .map { WorldEntity(id: $0.id, name: $0.name) }
//        }
//        
//      
//        private func loadWorlds() async -> [WorldEntity] {
//            await withCheckedContinuation { continuation in
//                WorldManager.shared.loadSavedWorlds {
//                    let worlds = WorldManager.shared.savedWorlds.map {
//                        WorldEntity(id: $0.id, name: $0.name)
//                    }
//                    continuation.resume(returning: worlds)
//                }
//            }
//        }
        
        /// Return all entities matching a set of identifiers.
        func entities(for identifiers: [UUID]) async throws -> [WorldEntity] {
            // 1) Wait for WorldManager to finish loading.
            let allWorlds = try await withCheckedThrowingContinuation { continuation in
                WorldManager.shared.loadSavedWorlds {
                    // This closure is called when loading is complete
                    let savedWorlds = WorldManager.shared.savedWorlds
                    continuation.resume(returning: savedWorlds)
                }
            }
            
            // 2) Filter based on the identifiers
            let matchedWorlds = allWorlds
                .filter { identifiers.contains($0.id) }
                .map { WorldEntity(id: $0.id, name: $0.name) }
            
            return matchedWorlds
        }
        
        /// Return a list of suggested (or "all") entities.
        func suggestedEntities() async throws -> [WorldEntity] {
            // 1) Wait for WorldManager to finish loading.
            let allWorlds = try await withCheckedThrowingContinuation { continuation in
                WorldManager.shared.loadSavedWorlds {
                    let savedWorlds = WorldManager.shared.savedWorlds
                    continuation.resume(returning: savedWorlds)
                }
            }
            
            // 2) Transform them into WorldEntity
            return allWorlds.map { WorldEntity(id: $0.id, name: $0.name) }
        }
    }
}


extension WorldEntity: IndexedEntity {
    

}
