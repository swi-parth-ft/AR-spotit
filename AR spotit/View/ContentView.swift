import SwiftUI
import ARKit
import AVFoundation
import Drops

struct ContentView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()
    @State private var audioEngine = AVAudioEngine()
       @State private var audioPlayer = AVAudioPlayerNode()
    
    @State private var currentInstruction: String = "Start scanning the Front Wall."
    @State private var progress: Float = 0.0
    @State private var arrowAngleY: Float = 0.0
    var directLoading: Bool
    @State private var hasLoadedWorldMap = false
    @Binding var findAnchor: String
    @State private var animate = false
    @State private var isFlashlightOn = false
    @Binding var isShowingFocusedAnchor: Bool
   @State private var isAddingNewAnchor: Bool = false
    
    @State private var shouldPlay = false
   @State private var isEditingAnchor: Bool = false
    @State private var nameOfAnchorToEdit: String = ""
    

    var body: some View {
        NavigationStack {
            
            
            VStack {
                ZStack {
                    
                    
                    ARViewContainer(sceneView: sceneView,
                                    anchorName: $currentAnchorName,
                                    worldManager: worldManager,
                                    findAnchor: findAnchor,
                                    showFocusedAnchor: $isShowingFocusedAnchor,
                                    shouldPlay: $shouldPlay,
                                    isEditingAnchor: $isEditingAnchor,
                                    nameOfAnchorToEdit: $nameOfAnchorToEdit)
                    .onAppear {
                        if findAnchor != "" {
                            worldManager.isShowingAll = false
                        }
                    }
                    .onDisappear {
                        shouldPlay = false
                        
                        if audioPlayer.isPlaying {
                               audioPlayer.stop()
                           }
                           if audioEngine.isRunning {
                               audioEngine.stop()
                               audioEngine.reset()
                           }
                    }
                    
                    .edgesIgnoringSafeArea(.all)
                    
                   
                    
                    
                    if !worldManager.isRelocalizationComplete {
                        
                        VStack {
                            
                            CircleView(text: !findAnchor.isEmpty ? findAnchor.filter { !$0.isEmoji } : currentRoomName, emoji: extractEmoji(from: findAnchor) ?? "🔍")
                                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width)
                            
                            Text("Move around slowly...")
                                .foregroundStyle(.white)
                                .font(.system(.title2, design: .rounded))
                                .bold()
                                .shadow(radius: 5)
                            
                            Spacer()
                                .frame(height: 200)
                            
                            Button {
                                toggleFlashlight()
                            } label: {
                                
                                   
                                    Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .foregroundStyle(.black)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white)
                                        .cornerRadius(25)
                                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                                        
                                
                                   
                            }
                        }
                         
                    } else {
                        VStack {
                            if !directLoading {
                                ProgressBar(progress: progress)
                                    .padding()
                                
                                // Scanning Instructions
                                Text(currentInstruction)
                                    .font(.headline)
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(10)
                                    .padding(.bottom, 20)
                            }
                            
                         
                            
                            Spacer()
                            HStack {
                                VStack(spacing: 10) {
                                    
                                    Button {
                                     //   worldManager.isAddingAnchor.toggle()
                                        isAddingNewAnchor.toggle()
                                    } label: {
                                        Image(systemName: "plus")
                                            .foregroundStyle(.black)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white)
                                            .cornerRadius(25)
                                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                                           
                                    }

                                    
                                    
                                    Button {
                                        toggleFlashlight()
                                    } label: {
                                        ZStack {
                                            if !isFlashlightOn {
                                                // White ring when flashlight is ON
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 4)
                                                    .frame(width: 48, height: 48)
                                            } else {
                                                // Solid white background when flashlight is OFF
                                                Circle()
                                                    .fill(Color.white)
                                                    .frame(width: 50, height: 50)
                                            }
                                            // Flashlight icon
                                            Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                                .foregroundStyle(isFlashlightOn ? .black : .white)
                                        }
                                    }
                                    .shadow(color: Color.white.opacity(0.5), radius: 10)

                                    
                                    

                                        
                                           
                                    
                                    if findAnchor != "" {
                                        
                                        Button {
                                          //  isShowingFocusedAnchor.toggle()
                                            worldManager.isShowingAll.toggle()
                                            let drop = Drop.init(title: worldManager.isShowingAll ? "Showing all items" : "Showing \(findAnchor) only")
                                            Drops.show(drop)
                                        } label: {
                                            
                                            ZStack {
                                                if !worldManager.isShowingAll {
                                                    // White ring when flashlight is ON
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 4)
                                                        .frame(width: 48, height: 48)
                                                } else {
                                                    // Solid white background when flashlight is OFF
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 50, height: 50)
                                                }
                                                // Flashlight icon
                                                Image(systemName: worldManager.isShowingAll ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                                                    .foregroundStyle(worldManager.isShowingAll ? .black : .white)
                                            }
                                        }
                                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                                        
                                        Button {
                                            shouldPlay.toggle()
                                        } label: {
                                            
                                            ZStack {
                                                if !shouldPlay {
                                                    // White ring when flashlight is ON
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 4)
                                                        .frame(width: 48, height: 48)
                                                } else {
                                                    // Solid white background when flashlight is OFF
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 50, height: 50)
                                                }
                                                // Flashlight icon
                                                Image(systemName: shouldPlay ? "speaker.2.fill" : "speaker.2")
                                                    .foregroundStyle(shouldPlay ? .black : .white)
                                            }
                                            
                                            
                                        }
                                        .shadow(color: Color.white.opacity(0.5), radius: 10)

                                    }
                                }
                                .padding()
                               
                                Spacer()
                            }
                            Spacer()
                            
                            VStack {
                                
                                
                                
                                HStack {
                         
                                    Button {
                                        shouldPlay = false
                                        findAnchor = ""
                                        worldManager.isWorldLoaded = false
                                        if audioPlayer.isPlaying {
                                               audioPlayer.stop()
                                           }
                                           if audioEngine.isRunning {
                                               audioEngine.stop()
                                               audioEngine.reset()
                                           }
                                        guard !currentRoomName.isEmpty else { return }
                                        worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
                                        
                                        let drop = Drop.init(title: "\(currentRoomName) saved")
                                        Drops.show(drop)
                                        dismiss()
                                    } label: {
                                        Text("Done")
                                            .foregroundStyle(.black)
                                            .frame(width: 100, height: 50)
                                            .background(Color.white)
                                            .cornerRadius(25)
                                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                                            
                                    }
                                    .onAppear {
                                        guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
                                        hasLoadedWorldMap = true
                                        
                                        worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                                    }
                       
                                    
                                    
                                    
                                }
                            }
                        }
                    }
                    
                }
                
                
            }
            .onAppear {
                worldManager.loadSavedWorlds()
            }
            .onChange(of: worldManager.scannedZones) {
                updateScanningProgress()
            }
            .onChange(of: worldManager.isShowingAll) {
                // We can access the coordinator if needed:
                if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                    coordinator.updateNodeVisibility(in: sceneView)
                }
            }
            .sheet(isPresented: $showAnchorList) {
                AnchorListView(sceneView: sceneView, worldManager: worldManager)
            }
            .sheet(isPresented: $isAddingNewAnchor) {
                AddAnchorView(anchorName: $currentAnchorName, worldManager: worldManager)
                    .presentationDetents([.fraction(0.6)])

            }
            .sheet(isPresented: $isEditingAnchor) {
                EditAnchorView(
                    anchorName: $nameOfAnchorToEdit,
                    onDelete: { anchorName in
                        // 1️⃣ Access the Coordinator via sceneView.delegate
                        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                            coordinator.deleteAnchor(anchorName: anchorName)
                        }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    },
                    onMove: { anchorName in
                        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                            coordinator.prepareToMoveAnchor(anchorName: anchorName)
                        }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    },
                    onRename: { oldName, newName in
                        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                            coordinator.renameAnchor(oldName: oldName, newName: newName)
                        }
                        // Optionally dismiss the sheet:
                        isEditingAnchor = false
                    }
                )
                .presentationDetents([.fraction(0.6)])

            }
        //    .navigationTitle(currentRoomName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        worldManager.isWorldLoaded = false
                        shouldPlay = false
                        findAnchor = ""
                        sceneView.session.pause()

                        if audioPlayer.isPlaying {
                               audioPlayer.stop()
                            print("audio stopped")
                           }
                           if audioEngine.isRunning {
                               audioEngine.stop()
                               audioEngine.reset()
                               print("engine stopped")
                           }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Text(currentRoomName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            worldManager.deleteWorld(roomName: currentRoomName) {
                                print("Deletion process completed.")
                                dismiss()
                            }
                        } label: {
                            Label("Delete World", systemImage: "trash")
                        }
                        
                        Button {
                            worldManager.shareWorld(currentRoomName: currentRoomName)
                        } label: {
                            Label("Share World", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
             
            }
            
        }
       
    }
    // Function to toggle flashlight
    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            print("Flashlight not available on this device")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if isFlashlightOn {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 1.0) // Maximum brightness
            }
            isFlashlightOn.toggle()
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle flashlight: \(error)")
        }
    }
 func extractEmoji(from string: String) -> String? {
     for char in string {
             if char.isEmoji {
                 return String(char)
             }
         }
         return nil
 }
 
    private func updateScanningProgress() {
        DispatchQueue.main.async {
            let totalZones = Float(worldManager.scanningZones.count)
            let scannedZonesCount = Float(worldManager.scannedZones.count)
            progress = scannedZonesCount / totalZones
            
            // List the zones in the order you'd like them scanned,
            // but the user can scan them in *any* order and we'll still update accordingly.
            let scanningOrder = [
                "Front Wall",
                "Left Wall",
                "Right Wall",
                "Floor",
                "Ceiling"
            ]
            
            // Check which zone from scanningOrder is still unscanned
            if let nextZone = scanningOrder.first(where: { !worldManager.scannedZones.contains($0) }) {
                // If we found an unscanned zone, guide the user to it
                currentInstruction = "Please scan the \(nextZone)."
            } else {
                // Otherwise, everything is scanned
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

// Helper view to add a blur effect
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var intensity: CGFloat? = nil

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
