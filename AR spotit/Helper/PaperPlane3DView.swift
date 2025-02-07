//
//  PaperPlane3DView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-07.
//


import SwiftUI
import SceneKit

struct PaperPlane3DView: UIViewRepresentable {
    /// The angle in degrees by which you want to rotate the 3D model.
    var angle: Double

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = false  // We generally want a static model, not user-pan

        // Load the .usdz model from your app’s bundle
        let scene = SCNScene(named: "Paper_Plane.usdz")!
        scnView.scene = scene
        // Traverse the scene and update all materials to be matte black.
        DispatchQueue.main.async {
            scene.rootNode.enumerateChildNodes { (node, _) in
                if let geometry = node.geometry {
                    // Create a new material with the matte black appearance.
                    let matteBlackMaterial = SCNMaterial()
                    matteBlackMaterial.diffuse.contents = UIColor.white
                    matteBlackMaterial.lightingModel = .physicallyBased
                    matteBlackMaterial.metalness.contents = 0.0
                    matteBlackMaterial.roughness.contents = 1.0

                    // Replace all materials with the new matte black material.
                    geometry.materials = [matteBlackMaterial]
                }
            }
        }
              
        if let planeNode = scene.rootNode.childNodes.first {
              // Increase the scale (tweak these values as needed)
            planeNode.scale = SCNVector3(1.9, 1.9, 1.9)
            
            let (minVec, maxVec) = planeNode.boundingBox
                let centerX = (minVec.x + maxVec.x) / 2.0
                let centerY = (minVec.y + maxVec.y) / 2.0
                let centerZ = (minVec.z + maxVec.z) / 2.0

                // Set the pivot so that the node rotates about its center
                planeNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)
          }
        // Add a basic camera pointing at the origin
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.5) // Adjust distance as needed
        scene.rootNode.addChildNode(cameraNode)

        // Optionally add a simple omnidirectional light if your model is too dark
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(0, 5, 5)
        scene.rootNode.addChildNode(lightNode)

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Rotate the top-level child node(s) based on `angle`.
        // If your "paper_plane.usdz" has multiple children, adjust accordingly.
        if let planeNode = scnView.scene?.rootNode.childNodes.first {
            // Convert degrees to radians for SceneKit
            planeNode.eulerAngles.x = Float.pi / 6
            SCNTransaction.begin()
                   // Set an animation duration (in seconds); adjust as needed.
                   SCNTransaction.animationDuration = 0.2
            
            planeNode.eulerAngles.y = Float((-angle * .pi / 180) + (3.14 / 2))
            
           // planeNode.eulerAngles.x = Float(3.14 / 2)
            SCNTransaction.commit()


        }
    }
}
