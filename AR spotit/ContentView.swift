import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()

    var body: some View {
        VStack {
            ARViewContainer(sceneView: sceneView,
                            anchorName: $currentAnchorName,
                            worldManager: worldManager)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Button("Show Anchors") {
                        showAnchorList.toggle()
                    }
                    .padding()

                    TextField("Anchor Name (e.g., 'Purse')", text: $currentAnchorName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                }

                Text(currentRoomName)
                TextField("Room Name", text: $newRoom)
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
        .sheet(isPresented: $showAnchorList) {
            AnchorListView(sceneView: sceneView, worldManager: worldManager)
        }
    }
}
