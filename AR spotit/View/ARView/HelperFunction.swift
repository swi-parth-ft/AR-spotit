//
//  HelperFunction.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import SwiftUI
import CloudKit
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops

// MARK: - Helper Functions
extension AugmentedView {
    func playItshereMP3(sound: String, withAngle angle: Double) {
        guard let fileURL = Bundle.main.url(forResource: sound, withExtension: "mp3") else {
            print("❌ Could not find \(sound).mp3 in the project bundle.")
            return
        }
        
        // Map the angle to a pan value between -1.0 (full left) and 1.0 (full right).
        // Assuming -90° maps to -1.0, 0° to 0.0, and 90° to 1.0.
        let panValue = max(-1, min(Float(angle / 90.0), 1))
        audioPlayer.pan = panValue
        
        let minDistance: Double = 0.9
         let maxDistance: Double = 3.0
         let volume: Float
         if distance < minDistance {
             volume = 1.0
         } else if distance < maxDistance {
             let factor = Float((distance - minDistance) / (maxDistance - minDistance))
             volume = 1.0 - factor * 0.7 // 1.0 to 0.3 decrease
         } else {
             volume = 0.3
         }
         audioPlayer.volume = volume
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            // Attach and connect the audio player if not already done.
            audioEngine.attach(audioPlayer)
            audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
            audioPlayer.play()
        } catch {
            print("❌ Error loading/playing \(sound).mp3: \(error)")
        }
    }
    func onViewAppear() {
    if let arWorldMap = WorldManager.shared.sharedARWorldMap {
        recordName = AppState.shared.publicRecordName
        isOpeningSharedWorld = true
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            node.removeFromParentNode()
        }
        sceneView.debugOptions = []
        sceneView.session.pause()
        let configuration = ARWorldTrackingConfiguration()
        configuration.initialWorldMap = arWorldMap
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.sceneReconstruction = .mesh
        }
        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
            coordinator.worldIsLoaded = false
            coordinator.isLoading = true
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
            coordinator.worldIsLoaded = true
            print("World loaded. Ready to add new guide anchors.")
        }
        DispatchQueue.main.async {
            if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                sceneView.delegate = coordinator
                sceneView.session.delegate = coordinator
                print("Reassigned delegate after loading shared world.")
            }
        }
        worldManager.isWorldLoaded = true
        worldManager.isShowingARGuide = true
        print("World map loaded successfully.")
        print("✅ AR session started with the iCloud-shared map!")
        WorldManager.shared.sharedARWorldMap = nil
    } else {
        isOpeningSharedWorld = false
        worldManager.loadSavedWorlds {
            if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }),
                world.isCollaborative {
                isCollab = true
                recordName = world.publicRecordName ?? ""
                print("This world has public collaboration")
            }
            worldManager.getAnchorNames(for: currentRoomName) { fetchedAnchors in
                DispatchQueue.main.async {
                    if let world = worldManager.savedWorlds.first(where: { $0.name == currentRoomName }),
                        world.isCollaborative,
                        let recordName = world.publicRecordName {
                        iCloudManager.shared.fetchNewAnchors(for: recordName) { records in
                            DispatchQueue.main.async {
                                let fetchedNewAnchorNames = records.compactMap { $0["name"] as? String }
                                newAnchorsCount = fetchedNewAnchorNames.filter { !fetchedAnchors.contains($0) }.count
                                print("Fetched \(newAnchorsCount) new collaborative anchors.")
                            }
                        }
                    }
                }
            }
            guard directLoading, !currentRoomName.isEmpty, !hasLoadedWorldMap else { return }
            hasLoadedWorldMap = true
            worldManager.loadWorldMap(for: currentRoomName, sceneView: sceneView)
        }
    }
}
    
    
    func playItshereMP3(sound: String) {
    guard let fileURL = Bundle.main.url(forResource: sound, withExtension: "mp3") else {
        print("❌ Could not find \(sound).mp3 in the project bundle.")
        return
    }
    do {
        let audioFile = try AVAudioFile(forReading: fileURL)
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
        audioPlayer.play()
    } catch {
        print("❌ Error loading/playing \(sound).mp3: \(error)")
    }
}
    
    func toggleFlashlight() {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
        print("Flashlight not available on this device")
        return
    }
    do {
        try device.lockForConfiguration()
        if isFlashlightOn {
            device.torchMode = .off
        } else {
            try device.setTorchModeOn(level: 1.0)
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
}
