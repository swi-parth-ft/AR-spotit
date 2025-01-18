import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation


struct ARViewContainer: UIViewRepresentable {
    let sceneView: ARSCNView
    @Binding var anchorName: String
   
    @ObservedObject var worldManager: WorldManager
    var findAnchor: String
    @State private var tempAnchor: ARAnchor? // For moving the anchor

    @Binding var showFocusedAnchor: Bool
    
    @Binding var shouldPlay: Bool
    // Audio properties
       private let audioEngine = AVAudioEngine()
       private let audioPlayer = AVAudioPlayerNode()
       private let audioEnvironmentNode = AVAudioEnvironmentNode()
    @State private var findAnchorReference: ARAnchor?

    private func stopAudio() {
        audioPlayer.stop()
          audioEngine.stop()
          print("Audio stopped.")
      }
    
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
        
       // setupAudio()
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    
 
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, worldManager: worldManager)
    }
    
    private func setupAudio() {
        configureAudioSession()

        
            // Load the audio file
            guard let audioFileURL = Bundle.main.url(forResource: "ping", withExtension: "mp3"),
                  let audioFile = try? AVAudioFile(forReading: audioFileURL) else {
                print("Audio file not found.")
                return
            }

            // Attach nodes
            audioEngine.attach(audioPlayer)
            audioEngine.attach(audioEnvironmentNode)

            // Connect nodes
            audioEngine.connect(audioPlayer, to: audioEnvironmentNode, format: nil)
            audioEngine.connect(audioEnvironmentNode, to: audioEngine.mainMixerNode, format: nil)

            // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        // Loop the audio file indefinitely
            func scheduleAudio() {
                audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: {
                    scheduleAudio() // Recursively schedule audio
                })
            }

            scheduleAudio()
            audioPlayer.play()
        }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playback category and spatial mode
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            print("Audio session configured for spatial audio.")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
  
    
    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate, Sendable {
        private var lastAnimationUpdateTime: Date = Date()
        private var hapticEngine: CHHapticEngine?
        private var lastHapticTriggerTime: Date = Date()
        private var nextPulseTime: Date = .distantPast
        var parent: ARViewContainer
        var worldManager: WorldManager
        private var mergedMeshNode = SCNNode() // Merged mesh node for all anchors
        private var lastUpdateTime: Date = Date() // Throttle updates
        private let maxGuideAnchors = 50  // Example maximum number of guide anchors
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

        
        init(_ parent: ARViewContainer, worldManager: WorldManager) {
            self.parent = parent
            self.worldManager = worldManager
            super.init()
            setupHaptics()
            setupScanningZones()
        }
        
        func updateNodeVisibility(in sceneView: ARSCNView) {
                    let allNodes = sceneView.scene.rootNode.childNodes
                    for node in allNodes {
                        refreshVisibilityRecursive(node: node)
                    }
                }
                
        private func refreshVisibilityRecursive(node: SCNNode) {
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
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            
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
                
                // Place anchor at the raycast result's position
                let name = parent.anchorName.isEmpty ? "defaultAnchor" : parent.anchorName
                let anchor = ARAnchor(name: name, transform: result.worldTransform)
                sceneView.session.add(anchor: anchor)
                print("Placed anchor with name: \(name) at position: \(result.worldTransform.columns.3)")
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
                            print("Anchor moved to new position.")
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
                    presentAnchorOptions(anchorName: name, node: node)
                    return
                }
                currentNode = node.parent
            }

            print("No anchor hit detected in node hierarchy.")
        }
        
        func presentAnchorOptions(anchorName: String, node: SCNNode) {
            let alert = UIAlertController(title: "Anchor Options", message: "Choose an action for the anchor '\(anchorName)'", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
                self.promptForNewName(oldName: anchorName)
            }))
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                self.deleteAnchor(anchorName: anchorName)
            }))
            
            alert.addAction(UIAlertAction(title: "Move", style: .default, handler: { _ in
                self.prepareToMoveAnchor(anchorName: anchorName)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes
                    .filter({ $0.activationState == .foregroundActive })
                    .first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    
                    // Find the top-most view controller
                    var topController = rootViewController
                    while let presentedController = topController.presentedViewController {
                        topController = presentedController
                    }
                    
                    topController.present(alert, animated: true, completion: nil)
                } else {
                    print("No active window to present the alert.")
                }
            }
        }
        
        func promptForNewName(oldName: String) {
            let alert = UIAlertController(title: "Rename Anchor", message: "Enter a new name for the anchor.", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "New anchor name"
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
                if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                    self.renameAnchor(oldName: oldName, newName: newName)
                } else {
                    print("Invalid name. Rename aborted.")
                }
            }))
            
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes
                    .filter({ $0.activationState == .foregroundActive })
                    .first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                    
                    // Find the top-most view controller
                    var topController = rootViewController
                    while let presentedController = topController.presentedViewController {
                        topController = presentedController
                    }
                    
                    topController.present(alert, animated: true, completion: nil)
                } else {
                    print("No active window to present the alert.")
                }
            }
        }
        
        func deleteAnchor(anchorName: String) {
            guard let anchor = parent.sceneView.session.currentFrame?.anchors.first(where: { $0.name == anchorName }) else {
                print("Anchor with name \(anchorName) not found.")
                return
            }
            

            parent.sceneView.session.remove(anchor: anchor)
            print("Anchor '\(anchorName)' deleted.")
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
            
            print("Anchor renamed from \(oldName) to \(newName).")
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
        }
        
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
                } else if !worldManager.scannedZones.contains(zoneName) {
                    // If not scanned yet, show arrow pointing to that zone
//                    if currentArrowNode == nil {
//                        placeArrowInFrontOfCamera(targetPosition: zonePosition)
//                    } else {
//                        ensureArrowInView(currentArrowNode!, targetPosition: zonePosition)
//                    }
                }
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
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
                // If an emoji is present, create a flat plane with the emoji
                let emojiFont = UIFont.systemFont(ofSize: 100)
                let emojiSize = CGSize(width: 100, height: 100)
                guard let emojiImage = parent.imageFromLabel(
                    text: emoji,
                    font: emojiFont,
                    textColor: .black,
                    backgroundColor: .clear,
                    size: emojiSize
                ) else {
                    print("Failed to create emoji image.")
                    return
                }
                
                let planeSize: CGFloat = 0.1
                let emojiPlane = SCNPlane(width: planeSize, height: planeSize)
                let emojiMaterial = SCNMaterial()
                emojiMaterial.diffuse.contents = emojiImage
                emojiMaterial.isDoubleSided = true
                emojiPlane.materials = [emojiMaterial]
                
                let emojiNode = SCNNode(geometry: emojiPlane)
                emojiNode.position = SCNVector3(0, 0, 0)
                
                // Make it face the camera
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                emojiNode.constraints = [billboardConstraint]
                
                node.addChildNode(emojiNode)
            } else {
                let sphereGeometry = SCNSphere(radius: 0.03)
                sphereGeometry.firstMaterial?.diffuse.contents = UIColor.white
                let sphereNode = SCNNode(geometry: sphereGeometry)
                node.addChildNode(sphereNode)
            }
            
            // 2) “Frosted glass” panel above
            let panelWidth: CGFloat = 0.3
            let panelHeight: CGFloat = 0.1
            let cornerRadius: CGFloat = 0.02
            let extrusionDepth: CGFloat = 0.01
            
            let rect = CGRect(x: -panelWidth/2, y: -panelHeight/2, width: panelWidth, height: panelHeight)
            let roundedRectPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            
            let panelGeometry = SCNShape(path: roundedRectPath, extrusionDepth: extrusionDepth)
            let panelMaterial = SCNMaterial()
            panelMaterial.diffuse.contents = UIColor(white: 1.0, alpha: 0.6)
            panelMaterial.isDoubleSided = true
            panelGeometry.materials = [panelMaterial]
            
            let panelNode = SCNNode(geometry: panelGeometry)
            let verticalOffset: Float = 0.15
            panelNode.position = SCNVector3(0, 0.05 + verticalOffset, 0)
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y
            panelNode.constraints = [billboardConstraint]
            node.addChildNode(panelNode)
            
            // 3) Text plane
            let cleanAnchorName = anchorName.filter { !$0.isEmoji }
            let displayString = "\(cleanAnchorName)"
            let font = UIFont(name: "AppleColorEmoji", size: 20) ?? UIFont.systemFont(ofSize: 50)
            let imageSize = CGSize(width: 200, height: 100)
            guard let labelImage = parent.imageFromLabel(
                text: displayString,
                font: font,
                textColor: .black,
                backgroundColor: .clear,
                size: imageSize
            ) else {
                print("Failed to create label image")
                return
            }
            
            let textPlaneGeometry = SCNPlane(width: panelWidth, height: panelHeight)
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = labelImage
            textMaterial.isDoubleSided = true
            textPlaneGeometry.materials = [textMaterial]
            
            let textPlaneNode = SCNNode(geometry: textPlaneGeometry)
            textPlaneNode.position = SCNVector3(0, 0, extrusionDepth + 0.001)
            panelNode.addChildNode(textPlaneNode)
            
            print(parent.findAnchor)

            
            let shouldHide = !worldManager.isShowingAll && (anchorName != parent.findAnchor)
      
                node.isHidden = shouldHide
            
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
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            
            if let lightEstimate = frame.lightEstimate {
                   if lightEstimate.ambientIntensity < 100.0 { // Example threshold for low light
                       Drops.show("Low light detected. Turn on flash.")
                   }
               }
            
            
            // Throttle updates to avoid excessive computation
               let currentTime = Date()
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
                // Update audio position
                // Update the listener's position to match the camera
                parent.audioEnvironmentNode.listenerPosition = AVAudio3DPoint(
                    x: cameraPosition.x,
                    y: cameraPosition.y,
                    z: cameraPosition.z
                )
                
                parent.audioEnvironmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
                parent.audioEnvironmentNode.distanceAttenuationParameters.referenceDistance = 1.0 // Reference for volume
                parent.audioEnvironmentNode.distanceAttenuationParameters.maximumDistance = 10.0
                parent.audioEnvironmentNode.distanceAttenuationParameters.rolloffFactor = 1.0
                parent.audioEnvironmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
                
                // Update the audio source's position to match the anchor
                parent.audioEnvironmentNode.position = AVAudio3DPoint(
                    x: direction.x,
                    y: direction.y,
                    z: direction.z
                )
                
                // Adjust volume based on distance
                parent.audioPlayer.volume = max(0.1, 1.0 - (distance / 2.0))
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
            DispatchQueue.main.async {
                self.addJumpingAnimation(to: node, basedOn: clampedDistance)
            }
          //
//            // Add jumping animation
//            guard let node = parent.sceneView.scene.rootNode.childNode(withName: anchor.name ?? "", recursively: true) else {
//                return
//            }
//            addJumpingAnimation(to: node, basedOn: clampedDistance)
        }
        
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
            let newMax = Int(area * 15)
            print("Adjusted max guide anchors to \(newMax) based on plane size.")
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            relocalizationTask?.cancel()
            relocalizationTask = Task {
                switch camera.trackingState {
                case .normal:
                    print("Relocalization complete. Ready to add guide anchors.")
                    worldIsLoaded = true
                  

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 1)) {
                            self.worldManager.isRelocalizationComplete = true

                        }
                    }
                case .limited(.relocalizing):
                    print("Relocalizing...")
                    worldIsLoaded = false
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 1)) {
                            self.worldManager.isRelocalizationComplete = false
                        }
                    }
                default:
                    break
                }
            }
        }
        
        func addJumpingAnimation(to node: SCNNode, basedOn distance: Float) {
            // We need the node's name to track it in our dictionaries
            guard let anchorName = node.name else { return }

            if distance < 1.0 {
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
                return
            }
            // Update the recorded jump height.
            nodeJumpHeights[anchorName] = newJump

            // 4) Remove any existing jump, so we don't overlap animations.
            node.removeAction(forKey: "jumping")

            // 5) Create an absolute “move(to:)” up, then down. This guarantees no drift.
            let upPosition   = SCNVector3(basePos.x, basePos.y + newJump, basePos.z)
            let downPosition = basePos

            let moveUp   = SCNAction.move(to: upPosition,   duration: 0.5)
            let moveDown = SCNAction.move(to: downPosition, duration: 0.5)
            let jumpCycle = SCNAction.sequence([moveUp, moveDown])
            let repeatJump = SCNAction.repeatForever(jumpCycle)

            // 6) Run the repeatForever
            node.runAction(repeatJump, forKey: "jumping")
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


