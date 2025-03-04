//
//  WelcomeView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-03.
//


import SwiftUI
import AnimateText
import AVFAudio

struct WelcomeView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowedAnimation = false
    @State private var circleScale: CGFloat = 0.2      // Initially smaller
    @State private var arrowOffset: CGFloat = 300        // Arrow starts far below center
    @State private var circleOffset: CGFloat = -300      // Circles start far above center
    @State private var arrowOpacity: Double = 1.0        // Fully visible
    @State private var angle = 45
    
    @State private var containerHeight: CGFloat = UIScreen.main.bounds.height
    @State private var isShowingIcon = false
    @Environment(\.colorScheme) var colorScheme
    @State private var welcomeText = " "
    @State private var isShowingTips = false
    
    @AppStorage("isShowedWelcome") private var isShowedWelcomeGuide: Bool = false
    @State private var audioEngine = AVAudioEngine()
    @State private var audioPlayer = AVAudioPlayerNode()
    @Namespace private var iconNamespace

    func playItshereMP3(sound: String) {
        guard let fileURL = Bundle.main.url(forResource: sound, withExtension: "mp3") else {
            print("❌ Could not find \(sound).mp3 in the project bundle.")
            return
        }
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            audioEngine.attach(audioPlayer)
            audioEngine.connect(audioPlayer, to: audioEngine.mainMixerNode, format: audioFile.processingFormat)
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            audioPlayer.scheduleFile(audioFile, at: nil, completionHandler: nil)
            audioPlayer.play()
        } catch {
            print("❌ Error loading/playing \(sound).mp3: \(error)")
        }
    }
    var body: some View {
        ZStack {
            
   
            VStack {
                ZStack {
                    
                    // Arrow in the background
                    Image(systemName: "arrow.up")
                        .font(.system(size: 200, weight: .bold))
                        .foregroundStyle(.primary)
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                        .offset(y: arrowOffset)
                        .opacity(arrowOpacity)
                    
                    if isShowingIcon {
                        iconView()
                            .frame(width: 100, height: 100)
                            .zIndex(2)

                    }
                        
                        // Animated circles
                        ZStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 500, weight: .bold))
                                .foregroundStyle(.orange.opacity(0.7))
                                .shadow(color: Color.orange.opacity(0.3), radius: 10)
                                .scaleEffect(circleScale)
                                .symbolEffect(.breathe)
                            
                            Circle()
                                .fill(.orange)
                                .frame(width: 450)
                                .shadow(color: Color.orange.opacity(0.5), radius: 10)
                                .scaleEffect(circleScale)
                        }
                        .zIndex(1)
                        .matchedTransitionSource(id: "icon", in: iconNamespace)
                        
                        .offset(y: circleOffset)
                    
                }
                .rotationEffect(Angle(degrees: Double(angle)))
                .frame(height: containerHeight, alignment: .center)
                .onAppear {
                    // 1. Animate the circles coming to center and growing to full size.
                    withAnimation(.easeInOut(duration: 2)) {
                        circleScale = 1.0      // Circle grows to full size.
                        circleOffset = 0       // Circles move to center.
                    }
                    
                    // 2. Animate the arrow moving into center.
                    withAnimation(.easeInOut(duration: 1.5)) {
                        arrowOffset = 0        // Arrow moves to center.
                        angle = 0
                        
                    }
                    
                    // 3. Fade out the arrow after circles reach full size.
                    withAnimation(.easeInOut(duration: 0.5).delay(2)) {
                        arrowOpacity = 0.0     // Arrow fades out.
                        
                    }
                    
                    // 4. After the above animations, shrink the circle to simulate a ball.
                    withAnimation(.easeIn(duration: 0.5).delay(2.5)) {
                        circleScale = 0.03      // Circle reduces to a small ball.
                    }
                    
                    // 5. Animate the circle dropping to the bottom with a bounce effect.
                    withAnimation(.interpolatingSpring(stiffness: 500, damping: 3).delay(2.5)) {
                        containerHeight = 80  // Adjust the new height as needed.
                        
                        circleOffset = 10
                        isShowedAnimation = true
                        circleOffset = 50
                        
                        
                    }
                    
                    // 6. Replace the circles with your final icon image.
                    withAnimation(.spring(duration: 1).delay(3.5)) {
                        isShowingIcon = true
                        circleScale = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        playItshereMP3(sound: "itshere")

                    }
                }
                if isShowedAnimation {
                    VStack {
                        
                        
                        VStack {
                            
                            
                            AnimateText<ATOffsetEffect>($welcomeText)
                                .font(.system(.largeTitle, design: .rounded))
                                .bold()
                            if isShowingTips {
                                Text("Finding items & help finding items never been this easy!")
                                    .font(.system(.title3, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.horizontal)
                                    .bold()
                                    .foregroundStyle(.secondary)
                            }
                            
                        }
                        .padding(.top)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                welcomeText = "Welcome to it's here."
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                                withAnimation(.easeInOut(duration: 1)) {
                                    isShowingTips = true
                                    
                                }
                            }
                        }
                        
                        
                        if isShowingTips {
                                TipsView()
                                
                            Spacer()
                            // Dismiss or navigate button
                            Button(action: {
                                isShowedWelcomeGuide = true
                                
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Get Started")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                                    .bold()
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 55)
                                    .background(Color.primary.opacity(1))
                                    .cornerRadius(10)
                            }
                            .padding()
                            
                        }
                        
                    }
                    
                }
            }
            .frame(width: UIScreen.main.bounds.width)

            .conditionalModifier(UIDevice.isIpad, modifier: { view in
                view.padding(.top, 100)
            })
        }
        }
    }



#Preview {
    WelcomeView()
}
