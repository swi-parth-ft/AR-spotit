//
//  ExtractColor.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-14.
//

import UIKit

func getDominantColor(for emoji: String) -> UIColor {
    let size = CGSize(width: 50, height: 50)
    let label = UILabel(frame: CGRect(origin: .zero, size: size))
    label.text = emoji
    label.font = UIFont.systemFont(ofSize: 50)
    label.textAlignment = .center
    
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    label.layer.render(in: UIGraphicsGetCurrentContext()!)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    guard let cgImage = image?.cgImage else { return .gray }
    let ciImage = CIImage(cgImage: cgImage)
    
    let filter = CIFilter(name: "CIAreaAverage")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgRect: ciImage.extent), forKey: "inputExtent")
    
    guard let outputImage = filter.outputImage else { return .gray }
    var bitmap = [UInt8](repeating: 0, count: 4)
    let context = CIContext()
    context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
    
    return UIColor(red: CGFloat(bitmap[0]) / 255.0,
                   green: CGFloat(bitmap[1]) / 255.0,
                   blue: CGFloat(bitmap[2]) / 255.0,
                   alpha: CGFloat(bitmap[3]) / 255.0)
}
