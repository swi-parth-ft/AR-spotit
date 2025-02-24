//
//  ARSnapshotManager.swift
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
    func configureCoachingOverlay(for sceneView: ARSCNView, coordinator: Coordinator) {
        // 1. Create and add a blur view
        let blurView = UIVisualEffectView(effect: nil)  // Start with no blur
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
