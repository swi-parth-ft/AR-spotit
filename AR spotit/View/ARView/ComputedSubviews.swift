//
//  ComputedSubviews.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import SwiftUI
import CloudKit
import AnimateText
import CoreHaptics
import ARKit
import AVFoundation
import Drops

// MARK: - Computed Subviews

extension AugmentedView {
    
    /// Overlay for when the camera is pointing down and relocalization is complete.
    var cameraDownOverlay: some View {
    Group {
        if isCameraPointingDown && worldManager.isRelocalizationComplete {
            ZStack {
                VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                if findAnchor != "" {
                    VStack {
                        VStack {
                            ZStack {
                                if distance < 0.5 {
                                    if distance > 0.35 {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 240, weight: .bold))
                                            .foregroundStyle(.orange.opacity(0.4))
                                            .shadow(color: Color.orange.opacity(0.1), radius: 10)
                                            .symbolEffect(.pulse)
                                    }
                                    if distance > 0.2 {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 240, weight: .bold))
                                            .foregroundStyle(.orange.opacity(0.7))
                                            .shadow(color: Color.orange.opacity(0.3), radius: 10)
                                            .symbolEffect(.breathe)
                                    }
                                }
                                Circle()
                                    .fill(.orange)
                                    .frame(width: distance < 0.5 ? 200 : 40)
                                    .shadow(color: Color.orange.opacity(0.5), radius: 10)
                            }
                            .offset(y: -50)
                            if distance > 0.5 {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 240, weight: .bold))
                                    .foregroundStyle(.white)
                                    .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                            }
                        }
                        .rotationEffect(Angle(degrees: -angle))
                        .animation(.easeInOut(duration: 0.5), value: angle)
                    }
                }
            }
        }
    }
}
    
    /// Bottom overlay when relocalization is complete.
    var relocalizationBottomOverlay: some View {
    Group {
        if worldManager.isRelocalizationComplete {
            VStack {
                Spacer()
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                    .frame(width: UIScreen.main.bounds.width, height: 200)
                    .cornerRadius(22)
            }
            .ignoresSafeArea()
        }
    }
}
    
    /// Guide overlay shown when AR guide isn’t active or relocalization isn’t complete.
    var guideOverlay: some View {
    ZStack {
        CircleView(
            text: !findAnchor.isEmpty ? findAnchor.filter { !$0.isEmoji } : currentRoomName,
            emoji: extractEmoji(from: findAnchor) ?? "🔍"
        )
        .padding(.top)
        .frame(width: 800, height: 800)
        VStack {
            Spacer()
            Button {
                toggleFlashlight()
                HapticManager.shared.impact(style: .medium)
                animateButton = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateButton = false
                }
            } label: {
                Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.black)
                    .frame(width: 65, height: 65)
                    .background(Color.white)
                    .cornerRadius(40)
                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                    .scaleEffect(isPressed ? 1.3 : (animateButton ? 1.4 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: isPressed)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: animateButton)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25)
                    .updating($isPressed) { currentState, gestureState, _ in
                        gestureState = currentState
                    }
            )
            .sensoryFeedback(.impact(weight: .heavy, intensity: 5), trigger: isFlashlightOn)
            .padding(30)
        }
        .padding()
    }
}
    
    /// Scanning overlay shown when AR guide is active and relocalization is complete.
    var scanningOverlay: some View {
    VStack {
    
        if findAnchor != "" {
            HStack {
                VStack(alignment: .leading) {
                    Text("FINDING")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.gray)
                        .bold()
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    Text("\(findAnchor)")
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(.white)
                        .bold()
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    HStack {
                        if distance < 0.9 {
                            AnimateText<ATOffsetEffect>($itshere)
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(.white)
                                .bold()
                                .matchedGeometryEffect(id: "itshere", in: itshereNamespace)
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .onAppear {
                                    itshere = "it's here."
                                    animatedAngle = ""
                                }
                        } else {
                            Text("\(String(format: "%.2f", distance))m")
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(Color.white)
                                .bold()
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .contentTransition(.numericText(value: distance))
                                .onAppear {
                                    itshere = ""
                                }
                            AnimateText<ATOffsetEffect>($animatedAngle)
                                .font(.system(.largeTitle, design: .rounded))
                                .foregroundStyle(.white)
                                .bold()
                                .shadow(color: Color.white.opacity(0.5), radius: 10)
                                .onChange(of: angle) { _ in
                                    animatedAngle = "\(Direction.classify(angle: angle))."
                                }
                        }
                    }
                }
                Spacer()
            }
            .padding()
            
            HStack {
                if findAnchor != "" && !isCameraPointingDown {
                    if !worldManager.is3DArrowActive {
                        Image(systemName: "arrow.up")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.white)
                            .bold()
                            .matchedGeometryEffect(id: "arrow", in: arrowNamespace)
                            .rotationEffect(.degrees(-angle))
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)))
                            .animation(.easeInOut(duration: 0.7), value: angle)
                            .shadow(color: Color.white.opacity(0.5), radius: 10)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, -20)
        }
        Spacer()
        VStack {
            HStack(spacing: 10) {
                if !AppState.shared.isViewOnly {
                    Button {
                        isAddingNewAnchor.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 65, height: 65)
                            Image(systemName: "plus")
                                .foregroundStyle(.black)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: Color.white.opacity(0.5), radius: 10)
                }
                Button {
                    toggleFlashlight()
                    HapticManager.shared.impact(style: .medium)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isFlashlightOn ? Color.white : Color.black.opacity(0.5))
                            .frame(width: 65, height: 65)
                        Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .foregroundStyle(isFlashlightOn ? .black : .white)
                            .font(.title2)
                            .bold()
                    }
                }
                .shadow(color: isFlashlightOn ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                if isOpeningSharedWorld {
                    if findAnchor == "" {
                        Button {
                            showAnchorListSheet = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 65, height: 65)
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white)
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 10)
                    } else {
                        Button {
                            withAnimation {
                                findAnchor = ""
                            }
                            worldManager.isShowingAll = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                                Image(systemName: "xmark")
                                    .foregroundStyle(.black)
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                    }
                }
                if findAnchor != "" {
                    Button {
                        worldManager.isShowingAll.toggle()
                        let drop = Drop(title: worldManager.isShowingAll ? "Showing all items" : "Showing \(findAnchor) only")
                        Drops.show(drop)
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(worldManager.isShowingAll ? Color.white : Color.black.opacity(0.5))
                                .frame(width: 65, height: 65)
                            Image(systemName: worldManager.isShowingAll ? "circle.hexagongrid.fill" : "circle.hexagongrid")
                                .foregroundStyle(worldManager.isShowingAll ? .black : .white)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: worldManager.isShowingAll ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                    
                    Button {
                        shouldPlay.toggle()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(shouldPlay ? Color.white : Color.black.opacity(0.5))
                                .frame(width: 65, height: 65)
                            Image(systemName: shouldPlay ? "speaker.2.fill" : "speaker.2")
                                .foregroundStyle(shouldPlay ? .black : .white)
                                .font(.title2)
                                .bold()
                        }
                    }
                    .shadow(color: shouldPlay ? Color.white.opacity(0.5) : Color.black.opacity(0.3), radius: 10)
                }
            }
            .padding()
            HStack {
                if newAnchorsCount > 0 {
                    Button {
                        if let coordinator = sceneView.delegate as? ARViewContainer.Coordinator {
                            coordinator.addNewAnchorsFromPublicDatabase()
                            withAnimation {
                                newAnchorsCount = 0
                            }
                        }
                    } label: {
                        Text("Retrieve New Items")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.white)
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.blue)
                            .cornerRadius(22)
                            .shadow(color: Color.blue.opacity(0.4), radius: 10)
                    }
                }
                Button {
                    if AppState.shared.isiCloudShare {
                        AppState.shared.isiCloudShare = false
                    }
                    if AppState.shared.isViewOnly {
                        AppState.shared.isViewOnly = false
                    }
                    isFlashlightOn = false
                    shouldPlay = false
                    findAnchor = ""
                    worldManager.isWorldLoaded = false
                    guard !currentRoomName.isEmpty else { return }
                    if !isOpeningSharedWorld {
                        coordinatorRef?.stopAudio()
                        worldManager.saveWorldMap(for: currentRoomName, sceneView: sceneView)
                        let drop = Drop(title: "\(currentRoomName) saved")
                        Drops.show(drop)
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } else {
                        AppState.shared.isViewOnly = false
                        coordinatorRef?.stopAudio()
                        coordinatorRef?.pauseSession()
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                } label: {
                    Text("Done")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.black)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.white)
                        .cornerRadius(22)
                        .shadow(color: Color.white.opacity(0.5), radius: 10)
                }
                .onAppear {
                    // (Optional onAppear code)
                }
            }
            .padding(.horizontal)
        }
    }
}
}
