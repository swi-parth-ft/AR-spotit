//
//  TipsView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-03.
//


import SwiftUI
import CardStack

struct OnboardingTips: Identifiable {
    let id = UUID()
    var symbolName: String
    var description: String
    var color: Color
}
struct TipsView: View {
    // Sample tip data
    let tips: [OnboardingTips] = [
        OnboardingTips(symbolName: "arkit", description: "Create AR map for real world areas and add items to find it later.", color: .orange),
        OnboardingTips(symbolName: "person.2.fill", description: "Collaborate large area with others to mark items quickly. and make them available to everyone.", color: .blue),
        OnboardingTips(symbolName: "location.magnifyingglass", description: "Find items easily with AR and an arrow to guide you.", color: .green),
        OnboardingTips(symbolName: "accessibility.fill", description: "Find item with tri-sense; with dynamic sounds and haptics coming from item with arrow to guide.", color: .yellow)
    
    ]
    
    @State private var currentIndex: Int = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        CardStack(tips, currentIndex: $currentIndex) { tip in
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.5))
                .frame(width: 280, height: 400)
                .shadow(color: colorScheme == .dark ? .black : .gray, radius: 5)

                .overlay(
                    ZStack {
                        Image(systemName: tip.symbolName)
                            .font(.system(size: 165))
                            .foregroundStyle(tip.color)
                            .padding()
                            .bold()
                            .padding(.bottom, 50)
                        VisualEffectBlur(blurStyle: .systemThinMaterial)
                            .cornerRadius(12)
                        VStack(alignment: .center) {
                            Image(systemName: tip.symbolName)
                                .font(.system(size: 120))
                                .frame(width: 120)
                                .padding()
                            Text(tip.description)
                                .font(.system(.title3, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .bold()

                        }
                        .padding()

                    }
                )
                .onTapGesture {
                    // Handle selection (e.g., navigate or display more info)
                    print("Tapped")
                }

        }

        .padding()
        .padding(.horizontal, 40)
    }
}

#Preview {
    TipsView()
}
