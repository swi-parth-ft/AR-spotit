import SwiftUI
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops


enum Direction {
    case inFront
    case onRight
    case onLeft
    case behindYou

    static func classify(angle: Double) -> String {
        switch angle {
        case -30...30:
            return "In Front"
        case -160..<(-30):
            return "On Right"
        case 30...160:
            return "On Left"
        default: // Covers angles less than -160 or greater than 160
            return "Behind You"
        }
    }
}


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
    
    @State private var engine: CHHapticEngine?
    @State private var animateButton = false
    @GestureState private var isPressed = false // Gesture state variable for press detection
    
    @State private var angle: Double = 0.0 // Store the angle for the arrow rotation
    @State private var distance: Double = 0.0
    @State private var itshere = ""
    @State private var animatedAngle = ""
    @Namespace private var arrowNamespace

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
                                    nameOfAnchorToEdit: $nameOfAnchorToEdit,
                                    angle: $angle,
                                    distanceForUI: $distance)
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
                        
                        sceneView.session.pause()
                        
                    }
                    
                    .edgesIgnoringSafeArea(.all)
                    if worldManager.isRelocalizationComplete {
                        VStack {
                            Spacer()
                            VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                                .frame(width: UIScreen.main.bounds.width, height: 200)
                                .cornerRadius(22)
                        }
                        .ignoresSafeArea()
                    }
                    
                    
                    
                    if !worldManager.isShowingARGuide || !worldManager.isRelocalizationComplete {
                        
                        ZStack {
                            
                            CircleView(text: !findAnchor.isEmpty ? findAnchor.filter { !$0.isEmoji } : currentRoomName, emoji: extractEmoji(from: findAnchor) ?? "🔍")
                                .padding(.top)
                            
                                .frame(width: 800, height: 800)
                            
                            
                            
                            VStack {
                                Spacer()
                                Button {
                                    // toggleFlashlight()
                                } label: {
                                    
                                    
                                    Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .foregroundStyle(.black)
                                        .frame(width: 50, height: 50)
                                        .background(Color.white)
                                        .cornerRadius(25)
                                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                                        .scaleEffect(isPressed ? 1.3 : (animateButton ? 1.4 : 1.0))
                                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: animateButton)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.25)
                                        .updating($isPressed) { currentState, gestureState, transaction in
                                            gestureState = currentState
                                        }
                                        .onEnded { _ in
                                            
                                            toggleFlashlight()
                                            
                                            // Trigger the bouncy animation
                                            animateButton = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                animateButton = false
                                            }
                                        }
                                )
                                .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: isFlashlightOn)
                                
                                .padding(30)
                            }
                            .padding()
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
                            
                            
                            if findAnchor != "" {
                                
                                    HStack {
                                        
                                        if distance < 0.9 {
                                            AnimateText<ATOffsetEffect>($itshere)                                                                                           .font(.system(.largeTitle, design: .rounded))
                                                .foregroundStyle(.white)
                                                .bold()
                                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                                .onAppear {
                                                    itshere = "it's here."
                                                    animatedAngle = ""
                                                }
                                        } else {
                                    
                                        Text("\(String(format: "%.2f", distance))m")
                                            .font(.system(.largeTitle, design: .rounded))
                                            .foregroundStyle(Color.white)
                                            .bold()
                                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                                            .contentTransition(.numericText(value: distance))
                                            .onAppear {
                                                itshere = ""
                                            }
                                            
                                            
                                            AnimateText<ATOffsetEffect>($animatedAngle)                                                                                           .font(.system(.largeTitle, design: .rounded))
                                                .foregroundStyle(.white)
                                                .bold()
                                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                                .onChange(of: angle) {
                                                    animatedAngle = "\(Direction.classify(angle: angle))."
                                                }
                                        }
                                            
                                        Spacer()
                                    }
                                    .padding()
                                
                                HStack {
                                    if findAnchor != "" {
                                        if !worldManager.is3DArrowActive {
                                            PaperPlane3DView(angle: -angle)
                                                .frame(width: 200, height: 70, alignment: .leading)
                                                // Keep the same matchedGeometryEffect if desired:
                                                .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                                                .transition(.asymmetric(
                                                    insertion: .scale.combined(with: .opacity),
                                                    removal: .scale.combined(with: .opacity)))
                                                .animation(.easeInOut(duration: 0.7), value: angle)
                                                .shadow(color: Color.white.opacity(0.5), radius: 10)

                                        }
                                        
                                    }
                                        
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, -20)
                            }
                            
                            
                            Spacer()
                            VStack {
                                
                            
                                
                                HStack(spacing: 10) {
                                    
                                    Button {
                                        //   worldManager.isAddingAnchor.toggle()
                                        isAddingNewAnchor.toggle()
                                        HapticManager.shared.impact(style: .medium)
                                        
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
                                        HapticManager.shared.impact(style: .medium)
                                        
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
                                            HapticManager.shared.impact(style: .medium)
                                            
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
                                            HapticManager.shared.impact(style: .medium)
                                            
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
                                        
                                        HapticManager.shared.notification(type: .success)
                                        
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
                                        //                                        guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
                                        //                                        hasLoadedWorldMap = true
                                        //
                                        //                                        worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                                    }
                                    
                                    
                                    
                                    
                                }
                            }
                        }
                        
                    }
                    
                }
                
                
            }
            .onAppear {
                worldManager.loadSavedWorlds {
                    guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
                    hasLoadedWorldMap = true
                    
                    worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
                }
                
                
                
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
                        
                        HapticManager.shared.impact(style: .medium)
                        
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
                                HapticManager.shared.notification(type: .success)
                                
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
