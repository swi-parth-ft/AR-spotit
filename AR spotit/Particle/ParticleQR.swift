import SwiftUI
import UIKit

struct ParticleQRAnimation: View {
    /// The QR (or any) UIImage you want to sample.
    let image: UIImage?
    
    /// How many particles you want.
    let particleCount = 2000
    
    @State private var particles: [Particle2] = []
    @State private var dragPosition: CGPoint?
    @State private var dragVelocity: CGSize?
    
    /// Store the size of our animation canvas.
    @State private var canvasSize: CGSize = .zero
    
    /// Make sure we only create particles once.
    @State private var hasCreatedParticles = false
    
    /// A timer driving the animation update.
    let timer = Timer.publish(every: 1/120, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Canvas { context, size in
            // Draw each particle as a white circle, plus a red circle at its target for debugging.
            for particle in particles {
                // Current position (white)
                let currentPath = Path(ellipseIn: CGRect(
                    x: particle.x,
                    y: particle.y,
                    width: 2,
                    height: 2
                ))
                context.fill(currentPath, with: .color(.white.opacity(0.8)))
                
                // Target position (red) — helps you see the actual pattern being sampled
                let targetPath = Path(ellipseIn: CGRect(
                    x: particle.baseX,
                    y: particle.baseY,
                    width: 2,
                    height: 2
                ))
                context.fill(targetPath, with: .color(.red))
            }
        }
        // Give the canvas a fixed frame so its size is stable.
        .frame(width: 200, height: 200)
        // Capture the actual size once, then create particles once.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        canvasSize = geo.size
                        if !hasCreatedParticles {
                            createParticles()
                            hasCreatedParticles = true
                        }
                    }
            }
        )
        // Optional: handle drag gestures for interaction
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragPosition = value.location
                    dragVelocity = value.velocity
                }
                .onEnded { _ in
                    dragPosition = nil
                    dragVelocity = nil
                }
        )
        // Update the particles each frame
        .onReceive(timer) { _ in
            updateParticles()
        }
    }
    
    /// Samples dark pixels in the provided image, assigns them as each particle's target (baseX/baseY).
    private func createParticles() {
        guard let image = image, let cgImage = image.cgImage else {
            print("No valid image.")
            return
        }
        
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        
        // If your image has a scale (e.g. 2.0 or 3.0), account for that
        let scale = image.scale
        
        // The image's size in *points*
        let imagePointWidth = CGFloat(pixelWidth) / scale
        let imagePointHeight = CGFloat(pixelHeight) / scale
        
        // Center the image in our 200×200 canvas
        let offsetX = (canvasSize.width - imagePointWidth) / 2
        let offsetY = (canvasSize.height - imagePointHeight) / 2
        
        // Get raw pixel data
        guard let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            print("Could not access pixel data.")
            return
        }
        
        // Create the array of particles
        particles = (0..<particleCount).map { _ in
            var foundDarkPixel = false
            var xPixel = 0
            var yPixel = 0
            var attempts = 0
            
            // Randomly search for a dark pixel
            while !foundDarkPixel && attempts < 1000 {
                xPixel = Int.random(in: 0..<pixelWidth)
                yPixel = Int.random(in: 0..<pixelHeight)
                
                let pixelIndex = ((pixelWidth * yPixel) + xPixel) * 4
                let r = bytes[pixelIndex]
                let g = bytes[pixelIndex + 1]
                let b = bytes[pixelIndex + 2]
                
                // Calculate brightness from r,g,b
                let brightness = 0.299 * Double(r)
                                + 0.587 * Double(g)
                                + 0.114 * Double(b)
                
                // If brightness < 128 => "dark"
                // (Adjust if your QR is reversed or if you need a different threshold)
                if brightness < 128 {
                    foundDarkPixel = true
                }
                attempts += 1
            }
            
            // Convert that pixel coordinate into the canvas coordinate system
            let baseX = Double(xPixel) / Double(scale) + Double(offsetX)
            let baseY = Double(yPixel) / Double(scale) + Double(offsetY)
            
            // Particles start randomly in the canvas, for a "fly-in" effect
            return Particle2(
                x: Double.random(in: 0...Double(canvasSize.width)),
                y: Double.random(in: 0...Double(canvasSize.height)),
                baseX: baseX,
                baseY: baseY,
                density: Double.random(in: 5...20)
            )
        }
    }
    
    /// Updates each particle every frame, moving it toward its target (or handling drag).
    private func updateParticles() {
        for i in particles.indices {
            particles[i].update(dragPosition: dragPosition, dragVelocity: dragVelocity)
        }
    }
}

// MARK: - The Particle

struct Particle2 {
    /// Current position
    var x: Double
    var y: Double
    
    /// Target position (the "dark" pixel from the QR code)
    let baseX: Double
    let baseY: Double
    
    /// Some random factor for each particle’s speed or mass
    let density: Double
    
    /// This function is called 120 times per second to animate the particle
    mutating func update(dragPosition: CGPoint?, dragVelocity: CGSize?) {
        // --- For debugging, snap directly to the target. ---
        // x = baseX
        // y = baseY
        
        // --- For an actual "easing" approach, try something like: ---
        let easing = 0.05 // move 5% each frame
        x += (baseX - x) * easing
        y += (baseY - y) * easing
        
        // If you want to handle drag, add logic here. For example:
        if let dragPos = dragPosition {
            let dx = x - dragPos.x
            let dy = y - dragPos.y
            let dist = sqrt(dx*dx + dy*dy)
            let maxDist = 100.0
            let dragForce = max(0, (maxDist - dist) / maxDist)
            
            // Move away from drag
            x += dx * dragForce * 0.01
            y += dy * dragForce * 0.01
        }
    }
}
