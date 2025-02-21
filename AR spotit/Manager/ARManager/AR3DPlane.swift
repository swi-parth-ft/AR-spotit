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
    
    func imageFromSFSymbolStroke(
            symbolName: String,
            pointSize: CGFloat,
            strokeColor: UIColor = .black,
            strokeWidth: CGFloat = 12,
            fillColor: UIColor = .white,
            size: CGSize
        ) -> UIImage? {
            // Build an attributed string with a stroke
            let config = UIImage.SymbolConfiguration(pointSize: pointSize)
            guard let uiImage = UIImage(systemName: symbolName, withConfiguration: config) else { return nil }
            
            // If you want a tinted fill:
            let tinted = uiImage.withTintColor(fillColor, renderingMode: .alwaysOriginal)

            // Set up your NSAttributedString with stroke
            // (This is easiest if you draw text, but with SF Symbols you need a little more bridging:
            //  Typically you'd just do something like:
            //     let attString = NSAttributedString(string: "", attributes: [
            //        .strokeColor: strokeColor,
            //        .strokeWidth: -strokeWidth,
            //        .foregroundColor: fillColor,
            //        .font: yourFont
            //     ])
            //  But for SF Symbols as UIImage, you usually do the “offset” approach or a custom Core Graphics pass.)
            //
            //   => If you really want to keep SF Symbol as raster, you can do a shadow approach:
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            defer { UIGraphicsEndImageContext() }
            let ctx = UIGraphicsGetCurrentContext()!
            
            // Example: draw tinted symbol with a shadow simulating an outline
            ctx.setShadow(offset: .zero, blur: strokeWidth, color: strokeColor.cgColor)
            
            let rect = CGRect(origin: .zero, size: size)
            tinted.draw(in: rect)
            
            return UIGraphicsGetImageFromCurrentImageContext()
        }
    
    func createSymbolPlaneNode(symbolName: String) -> SCNNode {
            // 1) Generate the SF Symbol as a UIImage
            let desiredSize = CGSize(width: 200, height: 200)  // Adjust as needed
            guard let symbolImage = imageFromSFSymbolStroke(
                   symbolName: symbolName,
                   pointSize: 80,
                   
                   size: desiredSize
               ) else {
                   return SCNNode()
               }
            
            // 2) Create the plane
            let planeWidth: CGFloat  = 0.2  // Real-world meters in AR
            let planeHeight: CGFloat = 0.2
            let planeGeometry = SCNPlane(width: planeWidth, height: planeHeight)
            
            // 3) Create material with the SF Symbol image
            let material = SCNMaterial()
            material.diffuse.contents = symbolImage
            material.isDoubleSided = true
            material.lightingModel = .constant // So it appears bright & unlit if desired
            planeGeometry.materials = [material]
            
            // 4) Make a node from the geometry
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.name = "arrow3D"
            
            // 5) Constrain it to face the camera
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .Y  // or .all if you want total facing
            planeNode.constraints = [billboardConstraint]
            
            // 6) Optionally set a small offset in front or above an anchor
            planeNode.position = SCNVector3(0, 0.1, 0)
            
            return planeNode
        }
}
