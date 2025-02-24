//
//  LinkMetadataProvider.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-23.
//


import UIKit
import LinkPresentation

class LinkMetadataProvider: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let image: UIImage?
    
    init(url: URL, title: String, image: UIImage? = nil) {
        self.url = url
        self.title = title
        self.image = image
    }
    
    // Return a placeholder. It should match the type of item you’re sharing.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    // Return the actual URL.
    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
    
    // Supply the rich metadata so that link previews can be generated.
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let image = image {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}


import UIKit
import LinkPresentation

class FilePreviewMetadataProvider: NSObject, UIActivityItemSource {
    let fileURL: URL
    let title: String
    let thumbnail: UIImage?
    
    init(fileURL: URL, title: String, thumbnail: UIImage? = nil) {
        self.fileURL = fileURL
        self.title = title
        self.thumbnail = thumbnail
    }
    
    // Provide a placeholder of the same type as the shared item.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }
    
    // Provide the actual file URL.
    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return fileURL
    }
    
    // Supply rich metadata so that a preview can be generated.
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = fileURL
        metadata.url = fileURL
        metadata.title = title
        if let thumbnail = thumbnail {
            metadata.imageProvider = NSItemProvider(object: thumbnail)
        }
        return metadata
    }
}


import QuickLookThumbnailing
import UniformTypeIdentifiers
import UIKit

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL
        
        // Extract the base file name (e.g. "Bee1" from "Bee1.worldmap")
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        // Build the snapshot filename: e.g., "Bee1_snapshot.png"
        let snapshotFileName = "\(baseName)_snapshot.png"
        // Build the snapshot URL in the same directory as the world map file.
        let snapshotURL = fileURL.deletingLastPathComponent().appendingPathComponent(snapshotFileName)
        
        if let image = UIImage(contentsOfFile: snapshotURL.path) {
            let maxSize = request.maximumSize
            
            // Render the image to the requested size.
            let rendererFormat = UIGraphicsImageRendererFormat.default()
            rendererFormat.scale = UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: maxSize, format: rendererFormat)
            let thumbnail = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: maxSize))
            }
            
            let reply = QLThumbnailReply(contextSize: maxSize, currentContextDrawing: {
                thumbnail.draw(in: CGRect(origin: .zero, size: maxSize))
                return true
            })
            handler(reply, nil)
        } else {
            // Fallback: If no snapshot is found, provide a blank thumbnail.
            let reply = QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: {
                UIColor.lightGray.setFill()
                UIRectFill(CGRect(origin: .zero, size: request.maximumSize))
                return true
            })
            handler(reply, nil)
        }
    }
}
