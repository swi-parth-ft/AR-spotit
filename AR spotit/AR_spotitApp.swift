//
//  AR_spotitApp.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-03.
//

import SwiftUI
import SwiftData
import AppIntents


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
    @State private var isActive = false // Tracks if the splash screen is active

    var body: some Scene {
        WindowGroup {
            ZStack {
                            // Main Content View
                            WorldsView()
                 
                                // .environmentObject(worldManager)
                                .onOpenURL { url in
                                    handleIncomingWorldFile(url)
                                }
                                .sheet(isPresented: $worldManager.isImportingWorld) {
                                    ImportWorldSheet()
                                        .environmentObject(worldManager)
                                        .presentationDetents([.fraction(0.4)])
                                }

                            // Splash Screen
                            if !isActive {
                                PhysicsDotsAnimationView()
                                    .transition(.opacity) // Fade in/out transition
                                    .zIndex(1) // Ensure it's on top
                            }
                        }
                        .onAppear {
                            // Delay the splash screen for 1 second
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    self.isActive = true // Hide splash screen
                                }
                            }
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
