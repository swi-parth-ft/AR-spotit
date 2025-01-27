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

    @Parameter(title: "World Name")
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
        return .result(dialog: "Searching \(worldName)...")
    }
}

extension OpenWorldIntent: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: Self(),
            phrases: ["Open \(\.$worldName) in \(.applicationName)"],
            shortTitle: "Open World",
            systemImageName: "arkit"
        )
    }
}
