//
//  AnchorListSheet.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-11.
//

import SwiftUI
import ARKit


struct AnchorListSheet: View {
    let sceneView: ARSCNView
    let onSelectAnchor: (String) -> Void  // A closure to handle the user’s choice
    @Environment(\.colorScheme) var colorScheme
    // We'll compute the anchor names in a computed property
    @State private var anchorNames: [String] = []

    
    var body: some View {
        NavigationStack {
            
            List(anchorNames, id: \.self) { anchorName in
                Button {
                    onSelectAnchor(anchorName)
                } label: {
                    Text(anchorName)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
            }
            .navigationTitle("Items")
            .onAppear {
                            reloadAnchorNames()
                
                        }
        }
    }
    
    private func reloadAnchorNames() {
            guard let anchors = sceneView.session.currentFrame?.anchors else {
                anchorNames = WorldManager.shared.sharedWorldsAnchors
                
                return
            }
            anchorNames = anchors
                .compactMap { $0.name }
                .filter { $0 != "guide" }
        }
}
