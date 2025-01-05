import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var newRoom = ""
    @State private var showWorldsView = false

    var sceneView = ARSCNView()

    var body: some View {
        VStack {
            ARViewContainer(sceneView: sceneView,
                            anchorName: $currentAnchorName,
                            worldManager: worldManager)
            .edgesIgnoringSafeArea(.all)

            VStack {
                Button("Show Worlds") {
                    showWorldsView.toggle()
                }
                TextField("Anchor Name (e.g., 'Purse')", text: $currentAnchorName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Text(currentRoomName)
                TextField("Room Name", text: $newRoom)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                HStack {
                    Button("Save Map") {
                        guard !newRoom.isEmpty else { return }
                        worldManager.saveWorldMap(for: newRoom, sceneView: sceneView)
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
        .sheet(isPresented: $showWorldsView) {
            WorldsView(worldManager: worldManager)
        }
    }
}
