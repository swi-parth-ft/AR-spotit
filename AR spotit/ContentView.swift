import SwiftUI
import ARKit

struct ContentView: View {
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()

    
    @State private var currentInstruction: String = "Start scanning the Front Wall."
    @State private var progress: Float = 0.0
    
    var body: some View {
        VStack {
            ARViewContainer(sceneView: sceneView,
                            anchorName: $currentAnchorName,
                            worldManager: worldManager)
                .edgesIgnoringSafeArea(.all)

            VStack {
                
                ProgressBar(progress: progress)
                                    .padding(.horizontal)

                                // Scanning Instructions
                                Text(currentInstruction)
                                    .font(.headline)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)
                                    .padding(.bottom, 20)
                
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
        .onChange(of: worldManager.scannedZones) {
                   updateScanningProgress()
               }
        .sheet(isPresented: $showAnchorList) {
            AnchorListView(sceneView: sceneView, worldManager: worldManager)
        }
    }
    
    private func updateScanningProgress() {
        DispatchQueue.main.async {
            let totalZones = Float(worldManager.scanningZones.count)
            let scannedZones = Float(worldManager.scannedZones.count)
            progress = scannedZones / totalZones

            // Update instruction based on progress
            if worldManager.scannedZones.contains("Front Wall") && !worldManager.scannedZones.contains("Left Wall") {
                currentInstruction = "Now scan the Left Wall."
            } else if worldManager.scannedZones.contains("Left Wall") && !worldManager.scannedZones.contains("Right Wall") {
                currentInstruction = "Next, scan the Right Wall."
            } else if self.progress == 1.0 {
                currentInstruction = "Scanning complete! All zones covered."
            }
        }
    }
}


struct ProgressBar: View {
    var progress: Float

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .frame(height: 20)
                .foregroundColor(.gray.opacity(0.3))

            RoundedRectangle(cornerRadius: 10)
                .frame(width: CGFloat(progress) * 300, height: 20)
                .foregroundColor(.blue)
        }
    }
}
