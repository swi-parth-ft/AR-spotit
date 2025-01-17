//
//  AnchorListView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-09.
//


import SwiftUI
import ARKit

struct AnchorListView: View {
    var sceneView: ARSCNView
    @ObservedObject var worldManager: WorldManager
    @State private var anchorNames: [String] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(anchorNames, id: \.self) { anchorName in
                    Text(anchorName)
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteAnchor(named: anchorName)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Anchors")
            .onAppear(perform: loadAnchors)
            .toolbar {
                Button("Refresh") {
                    loadAnchors()
                }
            }
        }
    }

    private func loadAnchors() {
        // Ensure a world is loaded from the saved worlds
        guard let loadedWorld = worldManager.savedWorlds.first else {
            print("No world loaded. Please load a saved world to view anchors.")
            return
        }

        // Fetch anchor names directly for the loaded world
        worldManager.getAnchorNames(for: loadedWorld.name) { names in
            DispatchQueue.main.async {
                anchorNames = names
                if anchorNames.isEmpty {
                    print("No anchors found for the world: \(loadedWorld.name).")
                } else {
                    print("Loaded anchors: \(anchorNames.joined(separator: ", "))")
                }
            }
        }
    }

    private func deleteAnchor(named anchorName: String) {
        guard let anchor = sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
            print("Anchor \(anchorName) not found.")
            return
        }

        // Remove the anchor from the AR session
        sceneView.session.remove(anchor: anchor)
        print("Deleted anchor: \(anchorName)")

        // Update the AR world
        worldManager.saveWorldMap(for: worldManager.cachedAnchorNames.keys.first ?? "", sceneView: sceneView)

        // Refresh the list
        loadAnchors()
    }
}
