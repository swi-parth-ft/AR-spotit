//
//  AR_spotitApp.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import SwiftUI
import SwiftData


class AppState: ObservableObject {
    static let shared = AppState() // Singleton instance
    @Published var isWorldUpdated: Bool = false {
        didSet {
            print("isWorldUpdated changed to: \(isWorldUpdated)")
        }
    }
}


@main
struct AR_spotitApp: App {

    // Ideally pass WorldManager down via environment or as a singleton
    @StateObject var worldManager = WorldManager()

    var body: some Scene {
        WindowGroup {
            WorldsView()
                .environmentObject(worldManager)
                .onOpenURL { url in
                                    handleIncomingWorldFile(url)
                                }
                .sheet(isPresented: $worldManager.isImportingWorld) {
                            ImportWorldSheet()
                                .environmentObject(worldManager)
                                .presentationDetents([.fraction(0.4)])

                        }
        }
       
    }

    private func handleIncomingWorldFile(_ url: URL) {
        // Make sure it’s the right type (e.g., .arworld, .worldmap, etc.)
        guard url.pathExtension == "arworld" || url.pathExtension == "worldmap" else {
            print("Unknown file type: \(url.pathExtension)")
            return
        }

        // Hand off the URL to a helper in your WorldManager
        worldManager.importWorldFromURL(url) 
    }
}
