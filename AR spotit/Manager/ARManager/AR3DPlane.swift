//
//  AR3DPlane.swift
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
}
