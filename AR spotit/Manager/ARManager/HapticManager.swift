//
//  HapticManager.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-24.
//

import UIKit


class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Handle impact feedback
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Handle notification feedback
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
