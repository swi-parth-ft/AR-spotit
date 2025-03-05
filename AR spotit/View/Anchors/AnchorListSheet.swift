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
    @State private var anchorNames: [String] = ["test", "test2", "test", "test2"]
    @State private var searchText: String = ""

    var filteredAnchors: [String] {
           if searchText.isEmpty {
               return anchorNames
           } else {
               return anchorNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
           }
       }
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Search items in this map, Tap on an item find it in real world using AR.")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                List(filteredAnchors, id: \.self) { anchorName in
                    Button {
                        onSelectAnchor(anchorName)
                    } label: {
                        Text(anchorName)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Items")
                .searchable(text: $searchText, prompt: "Search anchors")
                .onAppear {
                    UISearchBar.appearance().tintColor = colorScheme == .dark ? .white : .black
                      reloadAnchorNames()
                    
                }
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

#Preview {
    AnchorListSheet(sceneView: ARSCNView(), onSelectAnchor: { _ in
        
    })
}
