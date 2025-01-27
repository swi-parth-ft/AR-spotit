//
//  OpenWorldIntent.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-26.
//


import AppIntents

struct OpenWorldIntent: AppIntent {
    static var title: LocalizedStringResource = "Open a World"

    @Parameter(title: "World Name")
    var worldName: String

    func perform() async throws -> some IntentResult {
        // Use NotificationCenter or a shared state to communicate with your app
        NotificationCenter.default.post(
            name: Notification.Name("OpenWorldNotification"),
            object: nil,
            userInfo: ["worldName": worldName]
        )
        return .result(dialog: "Opening \(worldName)")
    }
}

extension OpenWorldIntent: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        
            AppShortcut(
                intent: OpenWorldIntent(),
                phrases: ["Open \(\.$worldName) in \(.applicationName)"],
                shortTitle: "Open World",
                systemImageName: "arkit"
            )
        
    }
}
