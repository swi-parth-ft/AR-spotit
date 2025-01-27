//
//  OpenWorldIntent.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-26.
//
import AppIntents

/// This requires iOS 16.4 or newer
@available(iOS 16.4, *)
struct OpenWorldIntent: ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Open a World"

    @Parameter(title: "World Name", optionsProvider: WorldNameOptionsProvider())
    var worldName: String

    /// Returning 'some IntentResult & ProvidesDialog' so we can show a success message.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        
        // 1) Do any quick background work here.
        //    For example, post a notification that "worldName" is about to open.
        NotificationCenter.default.post(
            name: Notification.Name("OpenWorldNotification"),
            object: nil,
            userInfo: ["worldName": worldName]
        )

        // 2) Now request to continue in the foreground.
        //    The user will see a prompt: "Do you want to open the app?"
        try await requestToContinueInForeground("Ready to open \(worldName) in it's here.?")

        // 3) Once the user accepts, your app is brought to the foreground,
        //    and we resume right here INSIDE your app's process.
        return .result(dialog: "Loading \(worldName)...")
    }
}

struct OpenWorldShortcut: AppShortcutsProvider {
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
                "Find a item in \(.applicationName)",
                "Launch \(.applicationName) World",
                "Discover an item in \(.applicationName)",
                "Unlock World in \(.applicationName)",
                "Begin Search in \(.applicationName)",
                "Search in \(.applicationName)"
            ],
            shortTitle: "Search Area",
            systemImageName: "arkit"
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
