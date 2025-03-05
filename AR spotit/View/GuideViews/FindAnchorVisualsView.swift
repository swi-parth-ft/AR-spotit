
import SwiftUI
import CoreMotion

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var triggerAnimation = false
    @Published var triggerAnimation1 = false

    private var lastUpdateTime: TimeInterval?
    private var velocity: CGFloat = 0.0
    private let movementMultiplier: CGFloat = 10.0
    private let threshold: CGFloat = 0.1
    private var distanceMoved: CGFloat = 0.0
    private var animationTriggered = false
    private var isDubbed = false
    init() {
       
    }
    func start() {
        motionManager.deviceMotionUpdateInterval = 0.02
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] data, error in
                guard let self = self, let data = data else { return }
                let currentTime = data.timestamp
                
                DispatchQueue.main.async {
                    if let lastTime = self.lastUpdateTime {
                        let dt = currentTime - lastTime
                        // In portrait mode, moving forward gives negative z acceleration.
                        let forwardAcceleration = -data.userAcceleration.z
                        self.velocity += CGFloat(forwardAcceleration) * CGFloat(dt)
                        self.distanceMoved += self.velocity * CGFloat(dt) * self.movementMultiplier
                        
                        if self.distanceMoved < 0 {
                            self.distanceMoved = 0
                            self.velocity = 0
                        }
                        
                        if self.distanceMoved > 0.02 && !self.isDubbed {
                            self.triggerAnimation1 = true
                            self.isDubbed = true
                        }
                        // Trigger the animation once the threshold is exceeded.
                        if !self.animationTriggered && self.distanceMoved >= self.threshold {
                            self.animationTriggered = true
                            self.triggerAnimation = true
                            self.motionManager.stopDeviceMotionUpdates()
                        }
                    }
                    self.lastUpdateTime = currentTime
                    self.objectWillChange.send()
                }
            }
        }
    }
}

//import SwiftUI
//import CoreMotion
//
//// Motion manager that detects an initial movement and then animates to the final state.
//class MotionManager: ObservableObject {
//    private var motionManager = CMMotionManager()
//    @Published var distanceMoved: CGFloat = 0.0  // in meters
//    private var lastUpdateTime: TimeInterval?
//    private var velocity: CGFloat = 0.0
//    // Multiplier to amplify movement for UI responsiveness.
//    private let movementMultiplier: CGFloat = 10.0
//    // Threshold for triggering the final animation (a small forward movement).
//    private let threshold: CGFloat = 0.15
//    private var animationTriggered = false
//
//    init() {
//        // Update at 50 Hz.
//        motionManager.deviceMotionUpdateInterval = 0.02
//        
//        if motionManager.isDeviceMotionAvailable {
//            motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] (data, error) in
//                guard let self = self, let data = data else { return }
//                let currentTime = data.timestamp
//                
//                DispatchQueue.main.async {
//                    if let lastTime = self.lastUpdateTime {
//                        let dt = currentTime - lastTime
//                        // In portrait mode, moving forward gives negative z acceleration.
//                        let forwardAcceleration = -data.userAcceleration.z
//                        self.velocity += CGFloat(forwardAcceleration) * CGFloat(dt)
//                        self.distanceMoved += self.velocity * CGFloat(dt) * self.movementMultiplier
//                        
//                        if self.distanceMoved < 0 {
//                            self.distanceMoved = 0
//                            self.velocity = 0
//                        }
//                        
//                        // Once a small movement is detected, trigger a 2-second animation to complete the effect.
//                        if !self.animationTriggered && self.distanceMoved >= self.threshold {
//                            self.animationTriggered = true
//                            withAnimation(.easeInOut(duration: 1.0)) {
//                                self.distanceMoved = 0.5
//                            }
//                            self.motionManager.stopDeviceMotionUpdates()
//                        }
//                    }
//                    self.lastUpdateTime = currentTime
//                    self.objectWillChange.send()
//                }
//            }
//        }
//    }
//}
//
//struct FindAnchorVisualsView: View {
//    @StateObject var motionManager = MotionManager()
//    
//    var body: some View {
//        // Calculate progress from 0 to 1 (0 m to 0.5 m).
//        let fraction = min(1, motionManager.distanceMoved / 0.5)
//        
//        // Arrow's bottom padding goes from -400 (start) to 0 (final).
//        let arrowPadding = -400 * (1 - fraction)
//        // Circles' bottom padding goes from 400 (start) to 0 (final).
//        let circlePadding = 400 * (1 - fraction)
//        
//        // Base sizes.
//        let arrowSize: CGFloat = 200
//        let circleImageInitialSize: CGFloat = 30
//        let circleShapeInitialSize: CGFloat = 20
//        
//        // Target scales for circles so that they reach the arrow's size when fully moved.
//        let circleImageTargetScale = arrowSize / circleImageInitialSize
//        let circleShapeTargetScale = arrowSize / circleShapeInitialSize
//        
//        // Interpolate scale based on progress fraction.
//        let circleImageScale = 1 + fraction * (circleImageTargetScale - 1)
//        let circleShapeScale = 1 + fraction * (circleShapeTargetScale - 1)
//        
//        return ZStack {
//            // Background arrow.
//            Image(systemName: "arrow.up")
//                .font(.system(size: arrowSize, weight: .bold))
//                .foregroundStyle(.primary)
//                .shadow(color: Color.white.opacity(0.5), radius: 10)
//                .padding(.bottom, arrowPadding)
//            
//            // Animated circles.
//            ZStack {
//                Image(systemName: "circle.fill")
//                    .font(.system(size: circleImageInitialSize, weight: .bold))
//                    .foregroundStyle(.orange.opacity(0.7))
//                    .shadow(color: Color.orange.opacity(0.3), radius: 10)
//                    .scaleEffect(circleImageScale)
//                
//                Circle()
//                    .fill(.orange)
//                    .frame(width: circleShapeInitialSize)
//                    .shadow(color: Color.orange.opacity(0.5), radius: 10)
//                    .scaleEffect(circleShapeScale)
//            }
//            .padding(.bottom, circlePadding)
//            .zIndex(1)
//            
//            // Instruction overlay.
//            VStack {
//                Spacer()
//                Text("Move your iPhone forward to the item")
//                    .font(.title3)
//                    .padding()
//            }
//        }
//        // The view animates changes to reflect the motion manager's distance.
//        .animation(.easeInOut, value: motionManager.distanceMoved)
//    }
//}
//
//struct FindAnchorVisualsView_Previews: PreviewProvider {
//    static var previews: some View {
//        FindAnchorVisualsView()
//    }
//}
