//
//  ARHapticAndSound.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-18.
//

import SwiftUI
import ARKit
import CoreHaptics
import Drops
import AVFoundation
import CloudKit


extension ARViewContainer {

    
    func stopAudio() {
        audioPlayer.stop()
        audioEngine.stop()
        print("Audio stopped.")
    }
}

extension ARViewContainer.Coordinator {
    //MARK: Set up haptics
    func setupHaptics() {
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
    
    func pulseInterval(for distance: Float) -> TimeInterval {
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
    
    func playDub() {
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
}
