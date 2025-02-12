import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct QRview: View {
    var roomName: String
    
    // MARK: - State Variables
    @State private var shareURL: URL?
    @State private var qrImage: UIImage?
    @State private var showingShareSheet = false
    @Environment(\.colorScheme) var colorScheme
    // Create the CI context and QR filter
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Display the QR code image if available
                if let image = qrImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none) // Keeps the QR code sharp
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                } else {
                    ProgressView("Generating QR Code...")
                }
                
           
            }
            // Present the share sheet when needed
            .sheet(isPresented: $showingShareSheet) {
                if let image = qrImage {
                    ShareSheet(activityItems: [image])
                }
            }
            // Generate the URL and QR code when the view appears
            .onAppear {
                WorldManager.shared.iCloudManager.createShareLink(for: roomName) { url in
                    guard let url = url else {
                        print("Failed to create share URL.")
                        return
                    }
                    self.shareURL = url
                    self.qrImage = generateQRCode(from: url.absoluteString)
                }
            }
            .navigationTitle("Share \(roomName)")
            .toolbar {
                Button {
                    if qrImage != nil {
                        showingShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                }
                .disabled(qrImage == nil)

            }
        }
    }
    
    // MARK: - QR Code Generation
    /// Converts a string into a QR code UIImage.
    func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.message = data
        
        if let outputImage = filter.outputImage {
            // Scale up the image for better clarity
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgimg = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}

// MARK: - Share Sheet Wrapper
/// A SwiftUI wrapper for UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems,
                                   applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed.
    }
}

// MARK: - Preview
#Preview {
    QRview(roomName: "exampleRoom")
}
