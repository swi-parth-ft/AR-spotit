

import SwiftUI
import Vortex

struct CircleView: View {
    var text: String = "Hello!"
    var emoji: String = "🐮"
    
    var body: some View {
        ZStack {
            
            VStack {
               
                
                ParticleTextAnimation(text: emoji)
                    .frame(width: 300, height: 60)
                ParticleTextAnimation(text: "Searching")
                    .frame(width: 300, height: 60)
                    .padding(.top, -20)

                ParticleTextAnimation(text: text)
                    .frame(width: 300, height: 60)
                    .padding(.top, -20)
                
                Spacer()
               
            }
            VortexView(createRing()) {
                Circle()
                    .fill(.white)
                    .blur(radius: 0)
                    .frame(width: 12)
                    .tag("circle")
            }
                
            
            
                
        }

    }

    func createRing() -> VortexSystem {
        let system = VortexSystem(tags: ["circle"])

        // Center the emission in the parent
        system.position = [0.5, 0.5]

        // Use ellipse if your version supports it
        system.shape = .ring(radius: 0.8)

        // Other properties...
        system.speed = 0.01
        system.speedVariation = 0.1
        system.lifespan = 1
       // system.angle = .degrees(0)
        system.angleRange = .degrees(360)
        system.size = 0.3
        system.sizeVariation = 0.3
        
        return system
    }
}

#Preview { CircleView() }
