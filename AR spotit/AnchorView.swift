////
////  AnchorView.swift
////  AR spotit
////
////  Created by Parth Antala on 2025-01-03.
////
//
//import SwiftUI
//import ARKit
//
//struct AnchorView: View {
//    @StateObject private var worldManager = WorldManager()
//    @State private var currentRoomName = ""
//    @State private var currentAnchorName = "" // New state for anchor name
//    var sceneView = ARSCNView()
//    
//    var body: some View {
//        VStack {
//            ARViewContainer(sceneView: sceneView, currentAnchorName: $currentAnchorName, worldManager: worldManager)
//                .edgesIgnoringSafeArea(.all)
//            
//            VStack {
//                TextField("Anchor Name (e.g., purse, cap)", text: $currentAnchorName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding()
//                
//                TextField("Room Name", text: $currentRoomName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding()
//                
//                HStack {
//                    Button("Save Map") {
//                        guard !currentRoomName.isEmpty else { return }
//                        worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
//                    }
//                    .padding()
//                    
//                    Button("Load Map") {
//                        guard !currentRoomName.isEmpty else { return }
//                        worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
//                    }
//                    .padding()
//                }
//            }
//            .background(Color(white: 0.95))
//        }
//    }
//}
//
//#Preview {
//    AnchorView()
//}
