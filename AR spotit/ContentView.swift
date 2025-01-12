import SwiftUI
import ARKit
import AVFoundation
struct ContentView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()

    
    @State private var currentInstruction: String = "Start scanning the Front Wall."
    @State private var progress: Float = 0.0
    @State private var arrowAngleY: Float = 0.0
    var directLoading: Bool
    @State private var hasLoadedWorldMap = false
    @Binding var findAnchor: String
    @State private var animate = false
    @State private var isFlashlightOn = false
    
   
    
    private func configureNavigationBarAppearance(for titleColor: UIColor) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [.foregroundColor: titleColor]
            appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
            appearance.backgroundColor = .clear // Adjust as needed
        appearance.shadowColor = .clear

            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle) /// the default large title font
        titleFont = UIFont(
            descriptor:
                titleFont.fontDescriptor
                .withDesign(.rounded)? /// make rounded
                .withSymbolicTraits(.traitBold) /// make bold
                ??
                titleFont.fontDescriptor, /// return the normal title if customization failed
            size: titleFont.pointSize
        )
        
        /// set the rounded font
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
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
    
    var body: some View {
        NavigationStack {
            
            
            VStack {
                ZStack {
                    
                    
                    ARViewContainer(sceneView: sceneView,
                                    anchorName: $currentAnchorName,
                                    worldManager: worldManager,
                                    findAnchor: findAnchor)
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
                            
                            VStack {
                                
                                
                                
                                HStack {
                                    Button("Show Anchors") {
                                        showAnchorList.toggle()
                                    }
                                    .padding()
                                    
                                    if worldManager.isAddingAnchor {
                                        TextField("Anchor Name (e.g., 'Purse')", text: $currentAnchorName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .padding()
                                    }
                                    
                                }
                                
                                //  Text(currentRoomName)
                                
                                
                                
                                HStack {
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
                                    Button {
                                        guard !currentRoomName.isEmpty else { return }
                                        worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
                                        
                                        
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
                                    
                                    Button {
                                        worldManager.isAddingAnchor = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .foregroundStyle(.black)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white)
                                            .cornerRadius(25)
                                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                                           
                                    }
                                    
                                    
                                }
                            }
                        }
                    }
                    
                }
                
                
            }
            .onChange(of: worldManager.scannedZones) {
                updateScanningProgress()
            }
            .sheet(isPresented: $showAnchorList) {
                AnchorListView(sceneView: sceneView, worldManager: worldManager)
            }
            .onDisappear {
                configureNavigationBarAppearance(for: .black) // Restore default

            }
            .navigationTitle(currentRoomName)
            .toolbar {
                Menu {
                    Button {
                        worldManager.deleteWorld(roomName: currentRoomName) {
                            print("Deletion process completed.")
                        }
                    } label: {
                        Label("Delete World", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .onAppear {
                configureNavigationBarAppearance(for: .white)
            }
            
        }
       
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
