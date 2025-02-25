import SwiftUI
import CloudKit
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops

struct AugmentedView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject var worldManager = WorldManager()
    var currentRoomName = ""
    @State private var currentAnchorName = ""
    @State private var showAnchorList = false
    @State private var newRoom = ""
    var sceneView = ARSCNView()
    @State var audioEngine = AVAudioEngine()
    @State var audioPlayer = AVAudioPlayerNode()
    
    @State var progress: Float = 0.0
    @State private var arrowAngleY: Float = 0.0
    var directLoading: Bool
    @State var hasLoadedWorldMap = false
    @Binding var findAnchor: String
    @State private var animate = false
    @State var isFlashlightOn = false
    @Binding var isShowingFocusedAnchor: Bool
    @State var isAddingNewAnchor: Bool = false
    
    @State var shouldPlay = false
    @State private var isEditingAnchor: Bool = false
    @State private var nameOfAnchorToEdit: String = ""
    
    @State private var engine: CHHapticEngine?
    @State var animateButton = false
    @GestureState var isPressed = false // For press detection
    
    @State var angle: Double = 0.0 // Arrow rotation angle
    @State var distance: Double = 0.0
    @State var itshere = ""
    @State var animatedAngle = ""
    @State var isOpeningSharedWorld = false
    @State var showAnchorListSheet = false
    @State var isCollab = false
    @State var recordName: String = ""
    @Namespace var arrowNamespace
    @Namespace var itshereNamespace

    @State var newAnchorsCount: Int = 0
    @State var coordinatorRef: ARViewContainer.Coordinator? = nil
    @State var isCameraPointingDown: Bool = false
    @State var hasPlayedItshere = false
    @State private var timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    ARViewContainer(
                        sceneView: sceneView,
                        anchorName: $currentAnchorName,
                        worldManager: worldManager,
                        findAnchor: $findAnchor,
                        showFocusedAnchor: $isShowingFocusedAnchor,
                        shouldPlay: $shouldPlay,
                        isEditingAnchor: $isEditingAnchor,
                        nameOfAnchorToEdit: $nameOfAnchorToEdit,
                        angle: $angle,
                        distanceForUI: $distance,
                        roomName: currentRoomName,
                        isCollab: $isCollab,
                        recordName: $recordName,
                        isCameraPointingDown: $isCameraPointingDown,
                        onCoordinatorMade: { coord in
                            coordinatorRef = coord
                        }
                    )
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
                        sceneView.delegate = nil
                        sceneView.session.delegate = nil
                    }
                    .edgesIgnoringSafeArea(.all)
                    
                    // Overlay when camera is pointing down and relocalization is complete
                    cameraDownOverlay
                    
                    // Bottom overlay when relocalization is complete
                    relocalizationBottomOverlay
                    
                    // Either show the guide or the scanning overlay
                    if !worldManager.isShowingARGuide || !worldManager.isRelocalizationComplete {
                        guideOverlay
                    } else {
                        scanningOverlay
                    }
                }
            }
            .onAppear(perform: onViewAppear)
            .onChange(of: distance) { newDistance in
                if newDistance < 0.3 && !hasPlayedItshere {
                    hasPlayedItshere = true
                    playItshereMP3(sound: "itshere")
                } else if newDistance > 0.3 {
                    hasPlayedItshere = false
                }
            }
         
            .onChange(of: worldManager.isShowingAll) {
                DispatchQueue.main.async {
                    if let coref = coordinatorRef {
                        coref.updateNodeVisibility(in: sceneView)
                    } else {
                        print("coordinatorRef is nil")
                    }
                }
            }
            .onReceive(timer) { _ in
                print("Timer fired – findAnchor: \(findAnchor), angle: \(angle)")
                if !findAnchor.isEmpty && shouldPlay {
                    playItshereMP3(sound: "opened", withAngle: -angle)
                }
            }
            .onChange(of: worldManager.isRelocalizationComplete) {
                if worldManager.isRelocalizationComplete {
                    playItshereMP3(sound: "opened")
                }
            }
            .sheet(isPresented: $showAnchorListSheet) {
                AnchorListSheet(sceneView: sceneView, onSelectAnchor: { selectedAnchorName in
                    findAnchor = selectedAnchorName
                    print(findAnchor)
                    worldManager.isShowingAll = false
                    showAnchorListSheet = false
                })
                .conditionalModifier(!UIDevice.isIpad) { view in
                    view.presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $isAddingNewAnchor) {
                AddAnchorView(anchorName: $currentAnchorName, worldManager: worldManager)
                    .conditionalModifier(!UIDevice.isIpad) { view in
                        view.presentationDetents([.fraction(0.6)])
                    }
            }
            .sheet(isPresented: $isEditingAnchor) {
                EditAnchorView(
                    anchorName: $nameOfAnchorToEdit,
                    onDelete: { anchorName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.deleteAnchor(anchorName: anchorName, recId: recordName)
                                let drop = Drop(title: "\(anchorName) deleted")
                                Drops.show(drop)
                                print("Anchor '\(anchorName)' deleted.")
                            } else {
                                print("Coordinator is nil — even with stable ref (unexpected).")
                            }
                        }
                        isEditingAnchor = false
                    },
                    onMove: { anchorName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.prepareToMoveAnchor(anchorName: anchorName, recId: recordName)
                            }
                        }
                        isEditingAnchor = false
                    },
                    onRename: { oldName, newName in
                        DispatchQueue.main.async {
                            if let coordinator = coordinatorRef {
                                coordinator.renameAnchor(oldName: oldName, newName: newName, recId: recordName)
                            }
                        }
                        isEditingAnchor = false
                    }
                )
                .conditionalModifier(!UIDevice.isIpad) { view in
                    view.presentationDetents([.fraction(0.6)])
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if AppState.shared.isiCloudShare {
                            AppState.shared.isiCloudShare = false
                        }
                        if AppState.shared.isViewOnly {
                            AppState.shared.isViewOnly = false
                        }
                        worldManager.isWorldLoaded = false
                        shouldPlay = false
                        findAnchor = ""
                        coordinatorRef?.stopAudio()
                        coordinatorRef?.pauseSession()
                        sceneView.session.pause()
                        HapticManager.shared.impact(style: .medium)
                        if !isOpeningSharedWorld {
                            coordinatorRef?.pauseSession()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Text(currentRoomName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                        if isCollab || AppState.shared.isiCloudShare {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                                .symbolEffect(.breathe)
                        }
                    }
                }
            }
        }
    }
}
