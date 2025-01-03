import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var worldManager = WorldManager()
    @State private var currentRoomName = ""
    var sceneView = ARSCNView()
    
    var body: some View {
        VStack {
            ARViewContainer(sceneView: sceneView, worldManager: worldManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                TextField("Room Name", text: $currentRoomName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                HStack {
                    Button("Save Map") {
                        guard !currentRoomName.isEmpty else { return }
                        worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
                    }
                    .padding()
                    
                    Button("Load Map") {
                        guard !currentRoomName.isEmpty else { return }
                        worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                    }
                    .padding()
                }
            }
            .background(Color(white: 0.95))
        }
    }
}
