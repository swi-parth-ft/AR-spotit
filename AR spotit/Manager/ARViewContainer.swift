
import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation
import CloudKit


struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
    @ObservedObject var worldManager: WorldManager
    @Binding var findAnchor: String
    @State private var tempAnchor: ARAnchor? // For moving the anchor
    @Binding var showFocusedAnchor: Bool
    @Binding var shouldPlay: Bool
    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let audioEnvironmentNode = AVAudioEnvironmentNode()
    @State private var findAnchorReference: ARAnchor?
    @Binding var isEditingAnchor: Bool
    @Binding var nameOfAnchorToEdit: String
    private let coachingOverlay = ARCoachingOverlayView()
    @Binding var angle: Double
    @Binding var distanceForUI: Double
     var roomName: String
    @Binding var isCollab: Bool
    @Binding var recordID: String
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.delegate = context.coordinator
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.sceneDepth)
            print("Scene reconstruction with LiDAR enabled.")
        } else {
            print("LiDAR-based scene reconstruction is not supported on this device.")
        }
        
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = context.coordinator as any ARSessionDelegate
        
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleTap(_:))
        )
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(context.coordinator.handleLongPress(_:))
        )
        
        sceneView.addGestureRecognizer(longPressGesture)
        sceneView.addGestureRecognizer(tapGesture)
        
        configureCoachingOverlay(for: sceneView, coordinator: context.coordinator)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self, worldManager: worldManager)
        
        return coordinator
    }
    
    //MARK: Audio Setup functions
    private func setupAudio() {
        configureAudioSession()
        guard let audioFileURL = Bundle.main.url(forResource: "Morse", withExtension: "aiff"),
              let audioFile = try? AVAudioFile(forReading: audioFileURL) else {
            print("Audio file not found.")
            return
        }
        
        audioEngine.attach(audioPlayer)
        audioEngine.attach(audioEnvironmentNode)
        audioEnvironmentNode.renderingAlgorithm = .HRTF
        
        audioEngine.connect(audioPlayer, to: audioEnvironmentNode, format: audioFile.processingFormat)
        audioEngine.connect(audioEnvironmentNode, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        func scheduleAudio() {
            audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scheduleAudio() // Recursively schedule audio with a delay
                }
            })
        }
        
        scheduleAudio()
        audioPlayer.play()
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .mixWithOthers])
            try audioSession.setActive(true)
            print("Audio session configured for spatial audio.")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func stopAudio() {
        audioPlayer.stop()
        audioEngine.stop()
        print("Audio stopped.")
    }
    
    //MARK: 3D Paper plane
    func createPaperPlaneNode() -> SCNNode {
        // Load the .usdz scene from your bundle
        guard let paperPlaneScene = SCNScene(named: "Paper_Plane.usdz") else {
            // If it fails, return an empty node or handle gracefully
            print("Could not load Paper_Plane.usdz")
            return SCNNode()
        }
        
        // A container node to hold all children of the loaded scene
        let containerNode = SCNNode()
        
        // Move all children of the scene’s root into containerNode
        for child in paperPlaneScene.rootNode.childNodes {
            containerNode.addChildNode(child.clone())
        }
        
        containerNode.enumerateChildNodes { (node, _) in
            if let geometry = node.geometry {
                // Create a new material with a matte black appearance
                let matteBlackMaterial = SCNMaterial()
                matteBlackMaterial.diffuse.contents = UIColor.white
                matteBlackMaterial.lightingModel = .physicallyBased
                matteBlackMaterial.metalness.contents = 0.0
                matteBlackMaterial.roughness.contents = 1.0
                
                // Replace all existing materials with our matte black material
                geometry.materials = [matteBlackMaterial]
            }
        }
        
        // Give it the same name you used for your arrow code
        // so the rest of your logic still recognizes "arrow3D".
        containerNode.name = "arrow3D"
        
        // Optionally adjust scale
        containerNode.scale = SCNVector3(0.0001, 0.0001, 0.0001) // tweak as needed
        containerNode.eulerAngles.z = Float.pi / 2
        
        return containerNode
    }
    
    //MARK: Coordinator Class
    class Coordinator: NSObject, ARSCNViewDelegate, @preconcurrency ARSessionDelegate, Sendable, ARCoachingOverlayViewDelegate {
        private var lastAnimationUpdateTime: Date = Date()
        private var hapticEngine: CHHapticEngine?
        private var lastHapticTriggerTime: Date = Date()
        private var nextPulseTime: Date = .distantPast
        var parent: ARViewContainer
        var worldManager: WorldManager
        private var mergedMeshNode = SCNNode()
        private var lastUpdateTime: Date = Date()
        private let maxGuideAnchors = 50
        var placedGuideAnchors: [(transform: simd_float4x4, anchor: ARAnchor)] = []
        private var anchorGrid: [Int: [ARAnchor]] = [:]
        private let gridSize: Float = 1.0
        var worldIsLoaded: Bool = false
        private var duplicateDistanceThreshold: Float = 1
        var isLoading = false
        var processedPlaneAnchorIDs: Set<UUID> = []
        private var relocalizationTask: Task<Void, Never>?
        private var zoneEntryTimes: [String: Date] = [:]
        private var currentArrowNode: SCNNode?
        private var anchorNodes: [String: SCNNode] = [:]
        private var lastJumpHeight: Float = 0.0
        private var nodeBasePositions = [String: SCNVector3]()
        private var nodeJumpHeights = [String: Float]()
        private var isAudioPlaying = true
        var arrowWasOffScreen = false
        var blurViewEffect: UIVisualEffectView?
        var lastAnchorFetchTime: Date = .distantPast
        var publicRecord: CKRecord? = nil
        var relocalizationCount = 0

        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
            super.init()
            setupHaptics()
            setupScanningZones()
        }
        
        //MARK: Did change tracking state
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            relocalizationTask?.cancel()
            relocalizationTask = Task {
                switch camera.trackingState {
                case .normal:
                    //                    parent.coachingOverlay.removeFromSuperview()
                    
                    print("Relocalization complete. Ready to add guide anchors.")
                    worldIsLoaded = true
                    relocalizationCount += 1
                    
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        // withAnimation(.easeIn(duration: 1)) {
                        self.worldManager.isRelocalizationComplete = true
                        self.worldManager.isShowingARGuide = true
                        // }
                    }
                case .limited(.relocalizing):
                    print("Relocalizing...")
                    worldIsLoaded = false
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        //  withAnimation(.easeOut(duration: 1)) {
                        self.worldManager.isRelocalizationComplete = false
                        //  }
                    }
                default:
                    break
                }
            }
        }
        
        //MARK: Did add anchor
         func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
           
//             if self.parent.sceneView.session.currentFrame!.anchors.contains(where: { $0.name == anchor.name }) {
//                 return
//             }
//            if let name = anchor.name, name != "guide" {
//                
//                
//                if WorldManager.shared.currentWorldRecord != nil && WorldManager.shared.isCollaborative {
//                    // Assume you store the current shared world record in your WorldManager.
//                    iCloudManager.shared.saveAnchor(anchor, for: WorldManager.shared.currentRoomName, worldRecord: WorldManager.shared.currentWorldRecord!) { error in
//                        if let error = error {
//                            print("Error saving new anchor: \(error.localizedDescription)")
//                        } else {
//                            print("Anchor \(anchor.name) saved for collaboration.")
//                        }
//                    }
//                }
//            }
            node.name = anchor.name
            anchorNodes[anchor.name ?? ""] = node
            
            let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x,
                                              anchor.transform.columns.3.y,
                                              anchor.transform.columns.3.z)
            checkZoneCoverage(for: anchorPosition)
            
            if let planeAnchor = anchor as? ARPlaneAnchor {
                adjustMaxGuideAnchors(basedOn: planeAnchor)
                addGuideAnchorIfNeeded(newTransform: planeAnchor.transform)
            }
            
            // Visualization logic for “guide” anchor
            if let anchorName = anchor.name, anchorName == "guide" {
                let guideGeometry = SCNSphere(radius: 0.001)
                guideGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let guideNode = SCNNode(geometry: guideGeometry)
                node.addChildNode(guideNode)
                
                print("Visualizing guide anchor at position: \(anchor.transform.columns.3)")
                return
            }
            
            // For user-labeled anchors
            guard let anchorName = anchor.name else {
                print("No name found for anchor, skipping visualization.")
                return
            }
            
            print("Visualizing anchor with name: \(anchorName)")
            
            
            
            // 1) Show sphere or emoji
            let emoji = parent.extractEmoji(from: anchorName)
            if let emoji = emoji {
                let glassEmojiNode = createGlassEmojiNode(emoji: emoji)
                node.addChildNode(glassEmojiNode)
                // If an emoji is present, create a flat plane with the emoji
                
            } else {
                let sphereGeometry = SCNSphere(radius: 0.03)
                sphereGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let sphereNode = SCNNode(geometry: sphereGeometry)
                node.addChildNode(sphereNode)
            }
            //
            
            
            let cleanAnchorName = anchorName.filter { !$0.isEmoji }
            
            // Make an image for the text
            let labelFont: UIFont = {
                if let descriptor = UIFontDescriptor
                    .preferredFontDescriptor(withTextStyle: .title2)
                    .withDesign(.rounded) {
                    
                    // Example: size 30
                    return UIFont(descriptor: descriptor, size: 30)
                } else {
                    // Fallback if .rounded not available
                    return UIFont.systemFont(ofSize: 30)
                }
            }()
            
            let imageSize = CGSize(width: 400, height: 120)
            DispatchQueue.global(qos: .userInitiated).async {
                
                guard let labelImage = self.parent.imageFromLabel(
                    text: cleanAnchorName,
                    font: labelFont,
                    textColor: .white,
                    backgroundColor: .clear,
                    size: imageSize
                ) else {
                    print("Failed to create label image.")
                    return
                }
                //
                // Create a plane for the text
                let planeWidth: CGFloat = 0.3
                let planeHeight: CGFloat = 0.09 // a bit shorter than the width
                let textPlane = SCNPlane(width: planeWidth, height: planeHeight)
                
                let textMaterial = SCNMaterial()
                textMaterial.diffuse.contents = labelImage
                textMaterial.isDoubleSided = true
                textMaterial.lightingModel = .constant
                
                textPlane.materials = [textMaterial]
                
                let textNode = SCNNode(geometry: textPlane)
                // Position above the emoji or sphere
                textNode.position = SCNVector3(0, 0.07, 0)
                
                // Let the text face camera
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                textNode.constraints = [billboardConstraint]
                
                node.addChildNode(textNode)
            }
            //
            //            let cleanName = anchorName.filter { !$0.isEmoji }
            //             guard !cleanName.isEmpty else { return }
            //
            //            //  Create the 3D text node
            //             let textNode = create3DTextNode(
            //                 cleanName,
            //                 fontSize: 30,
            //                 extrusion: 2,       // try bigger to get more "paint tube" look
            //                 chamfer: 200,          // bigger chamfer for rounder edges
            //                 color: .white   // or your favorite color
            //             )
            //             textNode.position = SCNVector3(0, 0.07, 0)
            //
            //             // Make text face the camera (if desired)
            //             let billboardConstraint = SCNBillboardConstraint()
            //             billboardConstraint.freeAxes = .Y
            //             textNode.constraints = [billboardConstraint]
            
            //       node.addChildNode(textNode)
            let spotlightNode = SCNNode()
            let spotlight = SCNLight()
            spotlight.type = .spot
            spotlight.spotInnerAngle = 30
            spotlight.spotOuterAngle = 60
            spotlight.intensity = 50
            spotlight.temperature = 10000
            
            spotlight.castsShadow = true // Enable shadows for better visual impact
            
            spotlightNode.light = spotlight
            spotlightNode.position = SCNVector3(0, 1, 0) // Above and slightly forward
            spotlightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // Point downward
            node.addChildNode(spotlightNode)
            
            //            if anchorName == "Fishing rod 🎣" {
            //                let audioSource = SCNAudioSource(fileNamed: "Morse.aiff")!
            //                audioSource.loops = true
            //                audioSource.isPositional = true
            //
            //                // Decode the audio from disk ahead of time to prevent a delay in playback
            //                audioSource.load()
            //                node.addAudioPlayer(SCNAudioPlayer(source: audioSource))
            //
            //            }
            
            //  addVolumetricSpotlightAbove(node)
            
            //            if anchor.name == parent.findAnchor {
            //                addVolumetricSpotlightAbove(node)
            //                }
            let shouldHide = !worldManager.isShowingAll && (anchorName != parent.findAnchor)
            
            node.isHidden = shouldHide
            
            
            
        }
        
        //MARK: Did Update Node
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            
            
            
            
            // Throttle updates to once every 0.5 seconds
            if Date().timeIntervalSince(lastUpdateTime) < 0.5 {
                return
            }
            lastUpdateTime = Date()
            
            if !isLoading {
                
                
                
                let meshGeometry = meshAnchor.geometry
                let vertexBuffer = meshGeometry.vertices.buffer
                let vertexCount = meshGeometry.vertices.count
                let stride = meshGeometry.vertices.stride
                let offset = meshGeometry.vertices.offset
                
                var vertices: [SIMD3<Float>] = []
                let pointer = vertexBuffer.contents()
                for i in 0..<vertexCount {
                    let vertexPointer = pointer.advanced(by: i * stride + offset)
                    let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    vertices.append(vertex)
                }
                
                let pointCloudNode = parent.createPointCloudNode(from: vertices)
                node.addChildNode(pointCloudNode)
                
                
                
            }
        }
        
        //MARK: Did update ARFrame
         func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let currentTime = Date()
             if AppState.shared.isiCloudShare {
                 
                 if self.worldManager.isRelocalizationComplete && relocalizationCount > 1 {
                     if currentTime.timeIntervalSince(lastAnchorFetchTime) > 10.0 {
                         lastAnchorFetchTime = currentTime
                         if let worldRecord = WorldManager.shared.currentWorldRecord {
                             iCloudManager.shared.fetchNewAnchors(for: worldRecord.recordID) { records in
                                 DispatchQueue.main.async {
                                     for record in records {
                                         if let transformData = record["transform"] as? Data {
                                             let transform = transformData.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
                                             
                                             
                                             let anchorName = record["name"] as? String
                                             let newAnchor = ARAnchor(name: anchorName ?? "noname", transform: transform)
                                             
                                             // Avoid adding duplicates by checking the transform.
                                             if !self.parent.sceneView.session.currentFrame!.anchors.contains(where: { $0.name == newAnchor.name }) {
                                                 self.parent.sceneView.session.add(anchor: newAnchor)
                                                 print("✅ Added new anchor \(newAnchor.name ?? "") from CloudKit.")
                                             }
                                         }
                                     }
                                 }
                             }
                         }
                         
                         
                         
                     }
                 }
//
            
                 if self.worldManager.isRelocalizationComplete == true {
                     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                         
                         if WorldManager.shared.sharedWorldsAnchors.isEmpty {
                             if let anchors = self.parent.sceneView.session.currentFrame?.anchors {
                                 WorldManager.shared.sharedWorldsAnchors = anchors.compactMap { $0.name }
                                     .filter { $0 != "guide" }
                             }
                         }
                     }
                 }
             }
            
            if let lightEstimate = frame.lightEstimate {
                if lightEstimate.ambientIntensity < 100.0 { // Example threshold for low light
                    //  Drops.show("Low light detected. Turn on flash.")
                }
            }
            
            
            // Throttle updates to avoid excessive computation
            //let currentTime = Date()
            guard currentTime.timeIntervalSince(lastAnimationUpdateTime) > 0.2 else { return } // Update every 0.2 seconds
            lastAnimationUpdateTime = currentTime
            // Retrieve light estimation
            if let lightEstimate = frame.lightEstimate {
                let ambientIntensity = lightEstimate.ambientIntensity // Brightness
                let ambientColorTemperature = lightEstimate.ambientColorTemperature // Kelvin
                updateAnchorLighting(intensity: ambientIntensity, temperature: ambientColorTemperature)
            }
            
            // Look for the anchor to track
            guard let anchor = session.currentFrame?.anchors.first(where: { $0.name == parent.findAnchor }) else {
                return
            }
            
            // Get distance from camera
            let cameraTransform = frame.camera.transform
            let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x,
                                              cameraTransform.columns.3.y,
                                              cameraTransform.columns.3.z)
            let anchorPosition = SIMD3<Float>(anchor.transform.columns.3.x,
                                              anchor.transform.columns.3.y,
                                              anchor.transform.columns.3.z)
            let distance = simd_distance(cameraPosition, anchorPosition)
            let clampedDistance = max(0.1, min(distance, 5.0)) // Clamp distance
            let direction = anchorPosition - cameraPosition
            
            
            
            //  let direction = anchorPosition - cameraPosition
            print("Direction Vector: \(direction)")
            
            // Project onto the horizontal plane
            let horizontalDirection = SIMD3<Float>(direction.x, 0, direction.z)
            print("Horizontal Direction: \(horizontalDirection)")
            
            // Normalize Direction
            let normalizedDirection = normalize(horizontalDirection)
            print("Normalized Direction: \(normalizedDirection)")
            
            // Calculate Angle
            
            
            let smoothedAngle = calculateAngleBetweenVectors(cameraTransform: cameraTransform, anchorPosition: anchorPosition)
            
            print("Normalized Angle in Degrees: \(smoothedAngle)")
            // Update the angle in the parent view
            DispatchQueue.main.async {
                self.parent.angle = smoothedAngle
                print("Angle in Degrees: \(smoothedAngle)")
                
                self.parent.distanceForUI = Double(distance)
            }
            // Turn distance into a pulsing interval
            let interval = pulseInterval(for: clampedDistance)
            
            // Trigger haptic feedback if it's time
            if Date() >= nextPulseTime {
                playDub()
                nextPulseTime = Date().addingTimeInterval(interval)
            }
            
            if parent.shouldPlay {
                if !isAudioPlaying {
                    isAudioPlaying = true
                    parent.setupAudio()
                }
                
                updateAudioPan(with: smoothedAngle)
                
                
                // Adjust volume based on distance
                parent.audioPlayer.volume = max(0.1, 1.0 - Float(distance) / 10.0)
                //
            } else {
                if isAudioPlaying {
                    isAudioPlaying = false
                    DispatchQueue.global(qos: .background).async {
                        self.parent.stopAudio()
                    }
                }            }
            guard let node = anchorNodes[anchor.name ?? ""] else {
                return
            }
            //            DispatchQueue.main.async {
            //                self.addJumpingAnimation(to: node, basedOn: clampedDistance)
            //            }
            
            //MARK: 3DArrow handling
            DispatchQueue.main.async {
                // Ensure a target anchor exists.
                guard !self.parent.findAnchor.isEmpty,
                      let anchor = session.currentFrame?.anchors.first(where: { $0.name == self.parent.findAnchor })
                else {
                    // Remove the arrow if no target anchor is available.
                    if let arrow3D = self.parent.sceneView.scene.rootNode.childNode(withName: "arrow3D", recursively: false) {
                        arrow3D.removeFromParentNode()
                    }
                    return
                }
                
                // Project the anchor’s 3D position to 2D screen coordinates.
                let anchorWorldPosition = SCNVector3(anchor.transform.columns.3.x,
                                                     anchor.transform.columns.3.y,
                                                     anchor.transform.columns.3.z)
                let projected = self.parent.sceneView.projectPoint(anchorWorldPosition)
                let anchorScreenPoint = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let bounds = self.parent.sceneView.bounds
                let isOnScreen = bounds.contains(anchorScreenPoint) && projected.z > 0
                
                if isOnScreen {
                    // If the arrow doesn't exist, create and add it.
                    var arrow3D: SCNNode
                    if let existingArrow = self.parent.sceneView.scene.rootNode.childNode(withName: "arrow3D", recursively: false) {
                        arrow3D = existingArrow
                    } else {
                        arrow3D = self.parent.createPaperPlaneNode()
                        arrow3D.opacity = 0 // start invisible
                        self.parent.sceneView.scene.rootNode.addChildNode(arrow3D)
                        
                        // Update state so the overlay arrow hides.
                        withAnimation(.easeInOut(duration: 0.7)) {
                            
                            self.parent.worldManager.is3DArrowActive = true
                        }
                        
                        // Animate a fade-in.
                        arrow3D.runAction(SCNAction.fadeIn(duration: 0.7)) {
                            // **Restart the jumping animation** once fade-in completes.
                            self.addJumpingAnimation(to: arrow3D, basedOn: clampedDistance)
                        }
                    }
                    
                    // Position the arrow above the anchor.
                    let target3D = SCNVector3(
                        anchorWorldPosition.x,
                        anchorWorldPosition.y + 0.10, // 30 cm above the anchor
                        anchorWorldPosition.z
                    )
                    
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.7
                    arrow3D.position = target3D
                    // Set arrow rotation as needed. For example, if you want it to point down when on-screen:
                    arrow3D.eulerAngles = SCNVector3(Float.pi / 2, 0, -Float.pi / 2)
                    SCNTransaction.commit()
                    
                    // (Optional) Update any stored positions or start animations here.
                    let arrowKey = arrow3D.name ?? "arrow3D"
                    self.nodeBasePositions[arrowKey] = target3D
                    
                    // Optionally restart any arrow animations if needed.
                    if self.arrowWasOffScreen || arrow3D.action(forKey: "jumping") == nil {
                        arrow3D.removeAction(forKey: "jumping")
                        self.addJumpingAnimation(to: arrow3D, basedOn: max(0.1, min(simd_distance(
                            SIMD3<Float>(anchor.transform.columns.3.x, anchor.transform.columns.3.y, anchor.transform.columns.3.z),
                            SIMD3<Float>(session.currentFrame!.camera.transform.columns.3.x,
                                         session.currentFrame!.camera.transform.columns.3.y,
                                         session.currentFrame!.camera.transform.columns.3.z)
                        ), 5.0)))
                        self.arrowWasOffScreen = false
                    }
                } else {
                    if let arrow3D = self.parent.sceneView.scene.rootNode.childNode(withName: "arrow3D", recursively: false) {
                        arrow3D.runAction(SCNAction.fadeOut(duration: 0.7)) {
                            arrow3D.removeFromParentNode()
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.7)) {
                                    
                                    self.parent.worldManager.is3DArrowActive = false
                                }
                            }
                        }
                    }
                }
            }
        }
        
        //MARK: Coaching overlay state changes
        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            UIView.animate(withDuration: 0.3) {
                self.blurViewEffect?.effect = nil
            }            }
        
        func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
            UIView.animate(withDuration: 0.3) {
                self.blurViewEffect?.effect = UIBlurEffect(style: .light)
            }
        }
        
        func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
            // Handle session reset if needed
            print("Coaching overlay requested session reset")
        }
        
        
        @MainActor func updateNodeVisibility(in sceneView: ARSCNView) {
            let allNodes = sceneView.scene.rootNode.childNodes
            for node in allNodes {
                refreshVisibilityRecursive(node: node)
            }
        }
        
        @MainActor private func refreshVisibilityRecursive(node: SCNNode) {
            // If the ARKit anchor's name is stored in `node.name`, we can rely on it here.
            guard let nodeName = node.name else {
                // Recur into children anyway, in case sub-nodes have meaningful names
                for child in node.childNodes {
                    refreshVisibilityRecursive(node: child)
                }
                return
            }
            
            // If isShowingAll => show everything => node.isHidden = false
            // If !isShowingAll => only show findAnchor => hide node if it’s not findAnchor
            let shouldHide = !worldManager.isShowingAll && (nodeName != parent.findAnchor)
            node.isHidden = shouldHide
            
            for child in node.childNodes {
                refreshVisibilityRecursive(node: child)
            }
        }
        
        //MARK: Set up haptics
        private func setupHaptics() {
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
                print("Haptics not supported on this device.")
                return
            }
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {
                print("Failed to start haptic engine: \(error)")
            }
        }
        
        func provideHapticFeedback(for distance: Float) {
            guard let hapticEngine = hapticEngine, Date().timeIntervalSince(lastHapticTriggerTime) > 0.1 else {
                return
            }
            lastHapticTriggerTime = Date()
            
            let intensity = min(1.0, max(0.1, 1.0 - distance / 3.0)) // Closer = higher intensity
            let sharpness = intensity
            
            let events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                    ],
                    relativeTime: 0,
                    duration: 0.1
                )
            ]
            
            do {
                let pattern = try CHHapticPattern(events: events, parameters: [])
                let player = try hapticEngine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                print("Failed to play haptic pattern: \(error)")
            }
        }
        
        private func pulseInterval(for distance: Float) -> TimeInterval {
            let maxDistance: Float = 3.0
            let minInterval: TimeInterval = 0.1
            let maxInterval: TimeInterval = 1.0
            
            // Clamp distance to [0, maxDistance]
            let clampedDist = max(0, min(distance, maxDistance))
            // fraction = 0.0 (very close) -> 1.0 (very far)
            let fraction = clampedDist / maxDistance
            
            let interval = minInterval + (maxInterval - minInterval) * Double(fraction)
            return interval
        }
        
        private func playDub() {
            guard let hapticEngine = hapticEngine else { return }
            
            let intensity: Float = 1.0
            let sharpness: Float = 0.5
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity,  value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: 0
            )
            
            do {
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try hapticEngine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                print("Failed to play haptic pattern: \(error)")
            }
        }
        
        //MARK: Handle tap gestures
        @MainActor @objc func handleTap(_ sender: UITapGestureRecognizer) {
            
            if worldManager.isAddingAnchor {
                let sceneView = parent.sceneView
                let location = sender.location(in: sceneView)
                
                // Create a raycast query
                guard let raycastQuery = sceneView.raycastQuery(
                    from: location,
                    allowing: .estimatedPlane,
                    alignment: .horizontal
                ) else {
                    print("Failed to create raycast query.")
                    return
                }
                
                // Perform the raycast
                let results = sceneView.session.raycast(raycastQuery)
                
                // Use the first result if available
                guard let result = results.first else {
                    print("No raycast result found.")
                    return
                }
                
                // Use a default name if the text field is empty.
                let baseName = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
                
                // Get the list of current anchor names.
                let currentAnchorNames = sceneView.session.currentFrame?.anchors.compactMap { $0.name } ?? []
                
                // Generate a unique name (e.g. "flag 🏴‍☠️" becomes "flag1 🏴‍☠️" if needed).
                let uniqueName = getUniqueAnchorName(baseName: baseName, existingNames: currentAnchorNames)
                
                
                // Place anchor at the raycast result's position
                let name = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
                let anchor = ARAnchor(name: uniqueName, transform: result.worldTransform)
                
                
                sceneView.session.add(anchor: anchor)
                if AppState.shared.isiCloudShare || parent.isCollab {
                    if (WorldManager.shared.currentWorldRecord != nil && WorldManager.shared.isCollaborative) {
                        iCloudManager.shared.saveAnchor(anchor, for: WorldManager.shared.currentRoomName, worldRecord: WorldManager.shared.currentWorldRecord!) { error in
                            if let error = error {
                                print("Error saving new anchor: \(error.localizedDescription)")
                            } else {
                                print("Anchor \(anchor.name ?? "") saved for collaboration.")
                            }
                        }
                    } else {
                        if publicRecord == nil {
                            
                            
                            CKContainer.default().publicCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: parent.recordID)) { record, error in
                                if let error = error {
                                    print("Error fetching world record from public DB: \(error.localizedDescription)")
                                    return
                                }
                                guard let pRecord = record else {
                                    
                                    print("No world record found for recordID: \(self.parent.recordID)")
                                    return
                                }
                                
                                self.publicRecord = record
                                print("new record created")
                                iCloudManager.shared.saveAnchor(anchor, for: self.parent.roomName, worldRecord: pRecord) { error in
                                    if let error = error {
                                        print("Error saving new anchor: \(error.localizedDescription)")
                                    } else {
                                        print("Anchor \(anchor.name ?? "") saved for collaboration.")
                                    }
                                }
                                
                            }
                        } else {
                            if let record = publicRecord {
                                iCloudManager.shared.saveAnchor(anchor, for: self.parent.roomName, worldRecord: record) { error in
                                    if let error = error {
                                        print("Error saving new anchor: \(error.localizedDescription)")
                                    } else {
                                        print("Anchor \(anchor.name ?? "") saved for collaboration.")
                                    }
                                }
                            }
                        }
                    }
                }
                
                
                if AppState.shared.publicRecordName != "" {
                    if publicRecord == nil {
                        let recordName = AppState.shared.publicRecordName
                        CKContainer.default().publicCloudDatabase.fetch(
                            withRecordID: CKRecord.ID(recordName: recordName)
                        ) { record, error in
                            if let pRecord = record {
                                
                                self.publicRecord = pRecord
                                // 3) Save anchors to the public record
                                iCloudManager.shared.saveAnchor(anchor,
                                                                for: self.parent.roomName,
                                                                worldRecord: pRecord) { error in
                                    if let error = error {
                                        print("Error saving anchor: \(error.localizedDescription)")
                                    } else {
                                        print("Anchor saved to public DB!")
                                    }
                                }
                                
                                
                            }
                        }
                    } else {
                        if let record = publicRecord {
                            iCloudManager.shared.saveAnchor(anchor,
                                                            for: self.parent.roomName,
                                                            worldRecord: record) { error in
                                if let error = error {
                                    print("Error saving anchor: \(error.localizedDescription)")
                                } else {
                                    print("Anchor saved to public DB!")
                                }
                            }
                        }
                       
                    }
                    
                }
                print("Placed anchor with name: \(uniqueName) at position: \(result.worldTransform.columns.3)")
                let drop = Drop.init(title: "\(uniqueName) placed")
                Drops.show(drop)
                if parent.findAnchor == "" {
                    HapticManager.shared.notification(type: .success)
                }
                worldManager.isAddingAnchor = false
            } else {
                if parent.tempAnchor != nil {
                    let sceneView = parent.sceneView
                    let location = sender.location(in: sceneView)
                    
                    // Create a raycast query
                    guard let raycastQuery = sceneView.raycastQuery(
                        from: location,
                        allowing: .estimatedPlane,
                        alignment: .horizontal
                    ) else {
                        print("Failed to create raycast query.")
                        return
                    }
                    
                    // Perform the raycast
                    let results = sceneView.session.raycast(raycastQuery)
                    
                    // Use the first result if available
                    guard let result = results.first else {
                        print("No raycast result found.")
                        return
                    }
                    
                    
                    if let tempAnchor = parent.tempAnchor {
                        // Place the saved anchor at a new position
                        let newAnchor = ARAnchor(name: tempAnchor.name ?? "defaultAnchor", transform: result.worldTransform)
                        sceneView.session.add(anchor: newAnchor)
                        parent.tempAnchor = nil
                        let drop = Drop.init(title: "\(tempAnchor.name ?? "") moved")
                        Drops.show(drop)
                        print("Anchor moved to new position.")
                        if parent.findAnchor == "" {
                            HapticManager.shared.notification(type: .success)
                        }
                    } else {
                        print("No anchor to move.")
                    }
                }
            }
        }
        
        @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
            guard sender.state == .began else { return } // Only handle on gesture start
            
            let location = sender.location(in: parent.sceneView)
            let hitResults = parent.sceneView.hitTest(location)
            
            print("Hit test results:")
            for result in hitResults {
                print("Node name: \(result.node.name ?? "nil")")
            }
            
            guard let hitResult = hitResults.first else {
                print("No hit results found.")
                return
            }
            
            // Traverse the node hierarchy to find the named node
            var currentNode: SCNNode? = hitResult.node
            while let node = currentNode {
                if let name = node.name {
                    print("Found anchor with name: \(name)")
                    parent.nameOfAnchorToEdit = name
                    parent.isEditingAnchor = true
                    
                    //  presentAnchorOptions(anchorName: name, node: node)
                    return
                }
                currentNode = node.parent
            }
            
            print("No anchor hit detected in node hierarchy.")
        }
        
        
        //MARK: Unique anchor names
        func getUniqueAnchorName(baseName: String, existingNames: [String]) -> String {
            // If the base name is not already used, return it immediately.
            if !existingNames.contains(baseName) {
                return baseName
            }
            
            // Try to detect an emoji at the end of the base name.
            // (This assumes your emoji is the very last character.)
            let trimmedBaseName: String
            let trailingEmoji: String?
            if let lastChar = baseName.last, lastChar.isEmoji {
                trailingEmoji = String(lastChar)
                // Remove the emoji and any trailing whitespace.
                trimmedBaseName = String(baseName.dropLast()).trimmingCharacters(in: .whitespaces)
            } else {
                trailingEmoji = nil
                trimmedBaseName = baseName
            }
            
            // Append a counter until we find a name that isn’t used.
            var counter = 1
            var newName: String
            repeat {
                if let emoji = trailingEmoji {
                    newName = "\(trimmedBaseName)\(counter) \(emoji)"
                } else {
                    newName = "\(trimmedBaseName)\(counter)"
                }
                counter += 1
            } while existingNames.contains(newName)
            
            return newName
        }
        
        
        //MARK: CURD on anchors
        func deleteAnchor(anchorName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
                print("Anchor with name \(anchorName) not found.")
                return
            }
            
            if let record = publicRecord {
                let predicate = NSPredicate(format: "worldRecordName == %@ AND name == %@", record.recordID.recordName, anchorName)
                
                // Create a query on the "Anchor" record type.
                let query = CKQuery(recordType: "Anchor", predicate: predicate)
                
                // Use the public database if your anchors are saved there.
                let publicDB = CKContainer.default().publicCloudDatabase
                
                publicDB.perform(query, inZoneWith: nil) { records, error in
                    if let error = error {
                        print("Error querying anchor: \(error.localizedDescription)")
                        return
                        }
                        
                    
                    
                    guard let records = records, let anchorRecord = records.first else {
                        print("No matching anchor record found for \(anchorName) in world \(record.recordID.recordName).")
                        return
                    }
                    
                    // Delete the fetched anchor record.
                    publicDB.delete(withRecordID: anchorRecord.recordID) { deletedRecordID, deleteError in
                        if let deleteError = deleteError {
                            print("Error deleting anchor: \(deleteError.localizedDescription)")
                        } else {
                            print("Anchor \(anchorName) deleted successfully from CloudKit.")
                        }
                    }
                }
            } else {
                CKContainer.default().publicCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: parent.recordID)) { record, error in
                    if let error = error {
                        print("Error fetching world record from public DB: \(error.localizedDescription)")
                        return
                    }
                    guard let pRecord = record else {
                        
                        print("No world record found for recordID: \(self.parent.recordID)")
                        return
                    }
                    
                    if let r = record {
                        self.publicRecord = r
                        print("new record created")
                        
                        let predicate = NSPredicate(format: "worldRecordName == %@ AND name == %@", r.recordID.recordName, anchorName)
                        
                        // Create a query on the "Anchor" record type.
                        let query = CKQuery(recordType: "Anchor", predicate: predicate)
                        
                        // Use the public database if your anchors are saved there.
                        let publicDB = CKContainer.default().publicCloudDatabase
                        
                        publicDB.perform(query, inZoneWith: nil) { records, error in
                            if let error = error {
                                print("Error querying anchor: \(error.localizedDescription)")
                                return
                            }
                            
                            
                            
                            guard let records = records, let anchorRecord = records.first else {
                                print("No matching anchor record found for \(anchorName) in world \(r.recordID.recordName).")
                                return
                            }
                            
                            // Delete the fetched anchor record.
                            publicDB.delete(withRecordID: anchorRecord.recordID) { deletedRecordID, deleteError in
                                if let deleteError = deleteError {
                                    print("Error deleting anchor: \(deleteError.localizedDescription)")
                                } else {
                                    print("Anchor \(anchorName) deleted successfully from CloudKit.")
                                }
                            }
                        }
                    }
                    
                }
            }
            
            parent.sceneView.session.remove(anchor: anchor)
            let drop = Drop.init(title: "\(anchorName) deleted")
            Drops.show(drop)
            print("Anchor '\(anchorName)' deleted.")
            if parent.findAnchor == "" {
                HapticManager.shared.notification(type: .success)
            }
            
        }
        
        func renameAnchor(oldName: String, newName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == oldName }) else {
                print("Anchor with name \(oldName) not found.")
                return
            }
            
            // Create a new anchor with the updated name
            let newAnchor = ARAnchor(name: newName, transform: anchor.transform)
            parent.sceneView.session.remove(anchor: anchor)
            parent.sceneView.session.add(anchor: newAnchor)
            let drop = Drop.init(title: "Renamed from \(oldName) to \(newName)")
            Drops.show(drop)
            print("Anchor renamed from \(oldName) to \(newName).")
            if parent.findAnchor == "" {
                HapticManager.shared.notification(type: .success)
            }
        }
        
        func prepareToMoveAnchor(anchorName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
                print("Anchor with name \(anchorName) not found.")
                return
            }
            
            // Store the anchor temporarily
            parent.tempAnchor = anchor
            parent.sceneView.session.remove(anchor: anchor)
            print("Anchor '\(anchorName)' prepared for moving.")
            let drop = Drop.init(title: "Tap new location to move \(anchorName)")
            Drops.show(drop)
            if parent.findAnchor == "" {
                HapticManager.shared.notification(type: .warning)
            }
        }
        
        //MARK: Add new Anchors from public database
        func addNewAnchorsFromPublicDatabase() {
            var uniqueRecords = 0
            if let world = worldManager.savedWorlds.first(where: { $0.name == parent.roomName }), world.isCollaborative,
               let publicRecordID = world.cloudRecordID {
                let recordID = CKRecord.ID(recordName: publicRecordID)
                iCloudManager.shared.fetchNewAnchors(for: recordID) { records in
                    DispatchQueue.main.async {
                        for record in records {

                            if let transformData = record["transform"] as? Data {
                                let transform = transformData.withUnsafeBytes { $0.load(as: simd_float4x4.self) }
                                
                                
                                let anchorName = record["name"] as? String
                                let newAnchor = ARAnchor(name: anchorName ?? "noname", transform: transform)
                                
                                // Avoid adding duplicates by checking the transform.
                                if !self.parent.sceneView.session.currentFrame!.anchors.contains(where: { $0.name == newAnchor.name }) {
                                    self.parent.sceneView.session.add(anchor: newAnchor)
                                    self.worldManager.anchorRecordIDs[record["name"] as? String ?? UUID().uuidString] = record.recordID.recordName

                                    print("✅ Added new anchor \(newAnchor.name ?? "") from CloudKit.")
                                    
                                    uniqueRecords += 1
                                    
                                    
                                }
                            }
                        }
                        
                        let drop = Drop.init(title: "\(uniqueRecords) new items added.")
                        Drops.show(drop)
                    }
                }
            }
        }
        
        
        //MARK: Scanning Zones
        private func setupScanningZones() {
            let origin = matrix_identity_float4x4 // Identity at origin
            
            // Some example “wall” offsets from the origin
            let frontWallTranslation = matrix_float4x4.translation(SIMD3<Float>(0, 0, -2))
            let leftWallTranslation  = matrix_float4x4.translation(SIMD3<Float>(-2, 0, 0))
            let rightWallTranslation = matrix_float4x4.translation(SIMD3<Float>(2, 0, 0))
            let floorTranslation     = matrix_float4x4.translation(SIMD3<Float>(0, -1.5, 0))
            let ceilingTranslation   = matrix_float4x4.translation(SIMD3<Float>(0, 2, 0))
            
            DispatchQueue.main.async {
                self.worldManager.scanningZones = [
                    "Front Wall": simd_mul(origin, frontWallTranslation),
                    "Left Wall":  simd_mul(origin, leftWallTranslation),
                    "Right Wall": simd_mul(origin, rightWallTranslation),
                    "Floor":      simd_mul(origin, floorTranslation),
                    "Ceiling":    simd_mul(origin, ceilingTranslation)
                ]
            }
        }
        
         func checkZoneCoverage(for position: SIMD3<Float>) {
            for (zoneName, zoneTransform) in worldManager.scanningZones {
                let zonePosition = SIMD3<Float>(zoneTransform.columns.3.x,
                                                zoneTransform.columns.3.y,
                                                zoneTransform.columns.3.z)
                
                if simd_distance(position, zonePosition) < 1.5 {
                    // If user is within 1.5m of that zone
                    if !worldManager.scannedZones.contains(zoneName) {
                        DispatchQueue.main.async {
                            self.worldManager.scannedZones.insert(zoneName)
                        }
                        print("\(zoneName) scanned after 2 seconds.")
                    }
                }
            }
        }
        
        //MARK: Create emoji sphere
        func createGlassEmojiNode(
            emoji: String,
            bubbleRadius: CGFloat = 0.05  // Radius of the glass sphere
        ) -> SCNNode {
            let parentNode = SCNNode()
            
            // Glass sphere
            let sphereGeometry = SCNSphere(radius: bubbleRadius)
            let glassMaterial = SCNMaterial()
            glassMaterial.lightingModel = .physicallyBased
            glassMaterial.diffuse.contents = UIColor.clear // Clear base color
            
            glassMaterial.metalness.contents = 0.0
            glassMaterial.roughness.contents = 0.05
            glassMaterial.diffuse.contents = UIColor(white: 1, alpha: 0.05)
            glassMaterial.transparency = 0.2
            glassMaterial.transparencyMode = .dualLayer
            glassMaterial.writesToDepthBuffer = false // Prevent depth conflicts
            sphereGeometry.materials = [glassMaterial]
            
            let sphereNode = SCNNode(geometry: sphereGeometry)
            sphereNode.renderingOrder = 0
            
            parentNode.addChildNode(sphereNode)
            
            // Emoji plane inside the sphere
            DispatchQueue.global(qos: .userInitiated).async {
                let emojiFont = UIFont.systemFont(ofSize: 70)
                let emojiSize = CGSize(width: 70, height: 70)
                
                guard let emojiImage = self.parent.imageFromLabel(
                    text: emoji,
                    font: emojiFont,
                    textColor: .black,
                    backgroundColor: .clear,
                    size: emojiSize
                ) else {
                    print("Failed to create emoji image.")
                    return
                }
                
                DispatchQueue.main.async {
                    let planeSize: CGFloat = bubbleRadius * 1
                    let emojiPlane = SCNPlane(width: planeSize, height: planeSize)
                    let emojiMaterial = SCNMaterial()
                    emojiMaterial.diffuse.contents = emojiImage
                    emojiMaterial.lightingModel = .constant // Ensure emoji ignores scene lighting
                    
                    emojiMaterial.isDoubleSided = true
                    emojiPlane.materials = [emojiMaterial]
                    
                    let emojiNode = SCNNode(geometry: emojiPlane)
                    emojiNode.position = SCNVector3(0, 0, 0.01)
                    emojiNode.renderingOrder = 1
                    // Make the emoji plane face the camera
                    let billboardConstraint = SCNBillboardConstraint()
                    billboardConstraint.freeAxes = .Y
                    emojiNode.constraints = [billboardConstraint]
                    
                    parentNode.addChildNode(emojiNode)
                }
            }
            
            return parentNode
        }
        
        //MARK: Create text
        func create3DTextNode(
            _ text: String,
            fontSize: CGFloat = 60,
            extrusion: CGFloat = 5,
            chamfer: CGFloat = 2,
            color: UIColor = .systemBlue
        ) -> SCNNode {
            // (A) Create an SCNText geometry
            let scnText = SCNText(string: text, extrusionDepth: extrusion)
            
            // Use a rounded SF font (fallback if not available)
            if let desc = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title1)
                .withDesign(.rounded) {
                scnText.font = UIFont(descriptor: desc, size: fontSize)
            } else {
                //    scnText.font = UIFont.systemFont(ofSize: fontSize)
            }
            
            // (B) Optional: round edges
            scnText.chamferRadius = chamfer
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.lightingModel = .physicallyBased
            material.metalness.contents = 0
            material.roughness.contents = 0.15
            scnText.materials = [material]
            
            
            let textNode = SCNNode(geometry: scnText)
            
            textNode.scale = SCNVector3(0.001, 0.001, 0.001)
            
            DispatchQueue.main.async {
                let (minBox, maxBox) = textNode.boundingBox
                let dx = maxBox.x - minBox.x
                let dy = maxBox.y - minBox.y
                let dz = maxBox.z - minBox.z
                textNode.pivot = SCNMatrix4MakeTranslation(dx / 2, dy / 2, dz / 2)
            }
            
            return textNode
        }
        
        func updateAnchorLighting(intensity: CGFloat, temperature: CGFloat) {
            let normalizedIntensity = min(max(intensity / 1000.0, 0.2), 2.0) // Normalize between 0.2 and 2.0
            
            for (_, node) in anchorNodes {
                // Adjust emission glow
                if let material = node.geometry?.firstMaterial {
                    material.emission.contents = UIColor(hue: 0.1, saturation: 0.8, brightness: normalizedIntensity, alpha: 1.0)
                }
                
                // Adjust light temperature
                node.light?.temperature = temperature
                node.light?.intensity = normalizedIntensity * 1000
            }
        }
        
        
        
        private func updateAudioPan(with angle: Double) {
            let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
            
            if normalizedAngle <= -160 || normalizedAngle >= 160 {
                parent.audioPlayer.pan = 0.0 // Behind: Center
                print("Playing from behind")
            } else {
                // Map angle (-90 to 90) to pan (-1.0 to 1.0)
                let panValue: Float = Float(normalizedAngle / 90.0) // Normalize to -1.0 to 1.0
                parent.audioPlayer.pan = panValue
                print("Playing with pan: \(panValue)")
            }
        }
        
        func normalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
            let length = simd_length(vector)
            return length > 0 ? vector / length : SIMD3<Float>(0, 0, 0)
        }
        
        func calculateAngleBetweenVectors(cameraTransform: simd_float4x4, anchorPosition: SIMD3<Float>) -> Double {
            // Extract the camera's forward vector (negative Z-axis)
            let cameraForward = SIMD3<Float>(-cameraTransform.columns.2.x, 0, -cameraTransform.columns.2.z)
            
            // Normalize the camera's forward vector
            let normalizedCameraForward = normalize(cameraForward)
            
            // Compute the direction vector from the camera to the anchor
            let directionToAnchor = anchorPosition - SIMD3<Float>(cameraTransform.columns.3.x, 0, cameraTransform.columns.3.z)
            
            let normalizedDirectionToAnchor = normalize(SIMD3<Float>(directionToAnchor.x, 0, directionToAnchor.z))
            
            let dotProduct = dot(normalizedCameraForward, normalizedDirectionToAnchor)
            let crossProduct = cross(normalizedCameraForward, normalizedDirectionToAnchor)
            
            let angleInRadians = atan2(crossProduct.y, dotProduct)
            
            let angleInDegrees = angleInRadians * (180.0 / .pi)
            
            return Double(angleInDegrees)
        }
        
        
        
        //MARK: Mesh functions
        func addMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let meshGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            let newNode = SCNNode(geometry: meshGeometry)
            newNode.name = meshAnchor.identifier.uuidString
            mergedMeshNode.addChildNode(newNode)
            
            if mergedMeshNode.parent == nil {
                parent.sceneView.scene.rootNode.addChildNode(mergedMeshNode)
            }
        }
        
        func updateMeshGeometry(from meshAnchor: ARMeshAnchor) {
            let updatedGeometry = createSimplifiedMeshGeometry(from: meshAnchor)
            if let childNode = mergedMeshNode.childNodes.first(where: { $0.name == meshAnchor.identifier.uuidString }) {
                childNode.geometry = updatedGeometry
            } else {
                addMeshGeometry(from: meshAnchor)
            }
        }
        
        func createSimplifiedMeshGeometry(from meshAnchor: ARMeshAnchor) -> SCNGeometry {
            let meshGeometry = meshAnchor.geometry
            
            // Vertex data
            let vertexBuffer = meshGeometry.vertices.buffer
            let vertexSource = SCNGeometrySource(
                buffer: vertexBuffer,
                vertexFormat: .float3,
                semantic: .vertex,
                vertexCount: meshGeometry.vertices.count,
                dataOffset: meshGeometry.vertices.offset,
                dataStride: meshGeometry.vertices.stride
            )
            
            // Face data: sample fewer faces for performance
            let facesBuffer = meshGeometry.faces.buffer
            let totalFaceCount = meshGeometry.faces.count
            let sampledFaceCount = min(totalFaceCount, 5000)
            let indexBufferLength = sampledFaceCount * 3 * MemoryLayout<UInt16>.size
            
            let facesPointer = facesBuffer.contents()
            let indexData = Data(bytes: facesPointer, count: indexBufferLength)
            let geometryElement = SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: sampledFaceCount,
                bytesPerIndex: MemoryLayout<UInt16>.size
            )
            
            // Create SCNGeometry
            let geometry = SCNGeometry(sources: [vertexSource], elements: [geometryElement])
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
            material.isDoubleSided = true
            geometry.materials = [material]
            
            return geometry
        }
        
        //MARK: Guide anchors
        private func addGuideAnchorIfNeeded(newTransform: simd_float4x4) {
            guard worldIsLoaded else {
                print("Skipping guide anchor placement. Relocalization not complete.")
                return
            }
            
            let position = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
            
            // Check for nearby guide anchors to avoid duplicates
            let isDuplicate = parent.sceneView.session.currentFrame?.anchors.contains(where: { anchor in
                anchor.name == "guide"
                && simd_distance(anchor.transform.columns.3, newTransform.columns.3) < 0.7
            }) ?? false
            
            if !isDuplicate {
                let guideAnchor = ARAnchor(name: "guide", transform: newTransform)
                parent.sceneView.session.add(anchor: guideAnchor)
                print("Added new guide anchor at \(position) in newly exposed area.")
            }
        }
        
        private func adjustMaxGuideAnchors(basedOn planeAnchor: ARPlaneAnchor) {
            let area = planeAnchor.extent.x * planeAnchor.extent.z
            let newMax = Int(area * 10)
            print("Adjusted max guide anchors to \(newMax) based on plane size.")
        }
        
        
        
        //MARK: Jumping Animations
        func addJumpingAnimation(to node: SCNNode, basedOn distance: Float) {
            // We need the node's name to track it in our dictionaries
            guard let anchorName = node.name else { return }
            
            if distance < 1.0  {
                node.removeAction(forKey: "jumping")
                if let basePos = nodeBasePositions[anchorName] {
                    let moveToOriginal = SCNAction.move(to: basePos, duration: 0.3) // Smooth reset in 0.3 seconds
                    node.runAction(moveToOriginal)
                }
                
                return
            }
            
            // 1) Figure out the base (original) position in world coordinates
            //    so the node always returns to exactly that spot.
            let basePos: SCNVector3
            if let storedPos = nodeBasePositions[anchorName] {
                // We already stored a base position
                basePos = storedPos
            } else {
                // First time we see this node, record its current *rendered* position
                basePos = node.presentation.position
                nodeBasePositions[anchorName] = basePos
            }
            
            // 2) Compute the new jump height: far anchor => bigger jump, near => smaller
            let maxJump: Float = 0.9 // max 0.5m up
            let clampedDist = max(0.1, min(distance, 3.0)) // keep distance in [0.1 ... 3.0]
            let newJump = maxJump * (clampedDist / 3.0) // range ~0..0.5
            // (Optional) you can clamp if you want to absolutely ensure 0 <= newJump <= 0.5:
            // let newJump = max(0.0, min(tempJump, maxJump))
            
            // 3) Check if this jump height is significantly different from last time.
            let oldJump = nodeJumpHeights[anchorName] ?? 0.0
            let delta = abs(newJump - oldJump)
            // If too small a difference, skip re-starting the animation.
            if delta < 0.05 {
                //  return
            }
            // Update the recorded jump height.
            nodeJumpHeights[anchorName] = newJump
            
            // 4) Remove any existing jump, so we don't overlap animations.
            node.removeAction(forKey: "jumping")
            
            // 5) Create an absolute “move(to:)” up, then down. This guarantees no drift.
            let upPosition   = SCNVector3(basePos.x, basePos.y + newJump, basePos.z)
            let downPosition = basePos
            
            // 3) Define gravity-based motion and damping for bounces
            let gravityAcceleration: Float = 9.8 // Gravity acceleration (m/s²)
            let initialVelocity = sqrt(2 * gravityAcceleration * newJump) // Initial velocity from height
            let durationUp = TimeInterval(initialVelocity / gravityAcceleration) // Time to reach the peak
            let durationDown = durationUp // Symmetric free fall
            
            // First jump (up and down)
            let moveUp = SCNAction.move(to: upPosition, duration: durationUp)
            moveUp.timingFunction = { t in t * t } // Accelerates upward
            
            let moveDown = SCNAction.move(to: downPosition, duration: durationDown)
            moveDown.timingFunction = { t in t * t } // Accelerates downward
            
            // Bounces with damping
            let bounces = 3
            var bounceActions: [SCNAction] = []
            var currentHeight = newJump
            for _ in 1...bounces {
                currentHeight *= 0.5 // Reduce height by 50% for each bounce
                let bounceUpPosition = SCNVector3(basePos.x, basePos.y + currentHeight, basePos.z)
                let bounceDurationUp = TimeInterval(sqrt(2 * gravityAcceleration * currentHeight) / gravityAcceleration)
                let bounceDurationDown = bounceDurationUp
                
                let bounceUp = SCNAction.move(to: bounceUpPosition, duration: bounceDurationUp)
                bounceUp.timingFunction = { t in t * t } // Accelerates upward
                
                let bounceDown = SCNAction.move(to: downPosition, duration: bounceDurationDown)
                bounceDown.timingFunction = { t in t * t } // Accelerates downward
                
                bounceActions.append(bounceUp)
                bounceActions.append(bounceDown)
            }
            
            // Add a wait action before repeating
            let waitAction = SCNAction.wait(duration: 0.75)
            
            // Combine actions into a full sequence
            let fullSequence = SCNAction.sequence([moveUp, moveDown] + bounceActions + [waitAction])
            
            // Repeat the full sequence forever
            let repeatAction = SCNAction.repeatForever(fullSequence)
            
            // Run the action
            node.runAction(repeatAction, forKey: "jumping")
        }
    }
}

// MARK: - Helper functions for generating images & point clouds
extension ARViewContainer {
    func createPointCloudNode(from vertices: [SIMD3<Float>]) -> SCNNode {
        let vertexData = Data(bytes: vertices, count: vertices.count * MemoryLayout<SIMD3<Float>>.size)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.size
        )
        
        var indices = [Int32](0..<Int32(vertices.count))
        let indexData = Data(bytes: &indices, count: indices.count * MemoryLayout<Int32>.size)
        
        let pointElement = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: vertices.count,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = UIColor.white
        pointMaterial.lightingModel = .constant
        pointMaterial.isDoubleSided = true
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [pointElement])
        geometry.materials = [pointMaterial]
        
        return SCNNode(geometry: geometry)
    }
    
    func imageFromLabel(text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor, size: CGSize) -> UIImage? {
        var generatedImage: UIImage?
        
        // Must be on the main thread to do UIKit drawing
        DispatchQueue.main.sync {
            let label = UILabel(frame: CGRect(origin: .zero, size: size))
            label.backgroundColor = backgroundColor
            label.textColor = textColor
            label.font = font
            label.textAlignment = .center
            label.text = text
            label.layer.cornerRadius = 10
            label.layer.masksToBounds = true
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }
            guard let context = UIGraphicsGetCurrentContext() else { return }
            label.layer.render(in: context)
            generatedImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        
        return generatedImage
    }
    
    func extractEmoji(from string: String) -> String? {
        for char in string {
            if char.isEmoji {
                return String(char)
            }
        }
        return nil
    }
}

extension ARViewContainer.Coordinator {
    func capturePointCloudSnapshotOffscreenClone(
        size: CGSize = CGSize(width: 800, height: 600)
    ) -> UIImage? {
        // 1) Create an empty scene with black background
        let tempScene = SCNScene()
        tempScene.background.contents = UIColor.black
        
        // 2) Clone the actual ARKit anchor nodes
        guard let currentFrame = parent.sceneView.session.currentFrame else {
            print("No currentFrame; cannot clone anchors.")
            return nil
        }
        for anchor in currentFrame.anchors {
            guard let anchorNode = parent.sceneView.node(for: anchor) else {
                continue
            }
            let anchorClone = anchorNode.clone()
            tempScene.rootNode.addChildNode(anchorClone)
        }
        
        // 3) Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.automaticallyAdjustsZRange = true
        tempScene.rootNode.addChildNode(cameraNode)
        
        // 4) Fit the bounding box in the camera's view
        let (minVec, maxVec) = tempScene.rootNode.boundingBox
        let sceneWidth  = maxVec.x - minVec.x
        let sceneHeight = maxVec.y - minVec.y
        let sceneDepth  = maxVec.z - minVec.z
        
        let center = SCNVector3(
            (minVec.x + maxVec.x) * 0.5,
            (minVec.y + maxVec.y) * 0.5,
            (minVec.z + maxVec.z) * 0.5
        )
        
        let epsilon: Float = 0.0001
        if sceneWidth < epsilon && sceneHeight < epsilon && sceneDepth < epsilon {
            // Very tiny or empty bounding box: just put camera 1m away
            cameraNode.position = SCNVector3(center.x, center.y, center.z + 1.0)
            cameraNode.look(at: center)
        } else {
            let camera = cameraNode.camera ?? SCNCamera()
            let verticalFovDeg = camera.fieldOfView
            let verticalFovRad = Float(verticalFovDeg) * .pi / 180
            let aspect = Float(size.width / size.height)
            
            let horizontalFovRad = 2 * atan(tan(verticalFovRad / 2) * aspect)
            
            let halfW = sceneWidth * 0.5
            let halfH = sceneHeight * 0.5
            
            let distanceForW = halfW / tan(horizontalFovRad / 2)
            let distanceForH = halfH / tan(verticalFovRad / 2)
            
            var requiredDistance = max(distanceForW, distanceForH)
            requiredDistance *= 1.1 // Add margin so it doesn't exactly touch the edges
            
            cameraNode.position = SCNVector3(center.x, center.y, center.z + requiredDistance)
            cameraNode.look(at: center)
        }
        
        // 5) Offscreen SCNView
        let scnView = SCNView(frame: CGRect(origin: .zero, size: size))
        scnView.scene = tempScene
        scnView.pointOfView = cameraNode
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        
        // 6) Snapshot
        return scnView.snapshot()
    }
    
}

extension ARViewContainer {
    private func configureCoachingOverlay(for sceneView: ARSCNView, coordinator: Coordinator) {
        // 1. Create and add a blur view
        var blurView = UIVisualEffectView(effect: nil)  // Start with no blur
        blurView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(blurView)
        
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: sceneView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor)
        ])
        
        coordinator.blurViewEffect = blurView
        
        coachingOverlay.session = sceneView.session
        coachingOverlay.delegate = coordinator // Assign the coordinator as the delegate
        coachingOverlay.goal = .tracking // You can choose other goals like .horizontalPlane, .verticalPlane, etc.
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(coachingOverlay)
        
        // Constrain the coaching overlay to the edges of the scene view
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: sceneView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: sceneView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: sceneView.heightAnchor)
        ])
    }
    
}



