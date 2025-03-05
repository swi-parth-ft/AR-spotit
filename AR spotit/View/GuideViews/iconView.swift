//
//  iconView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-03.
//

import SwiftUI

struct iconView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var angle: Double = 130
    @State private var pad: CGFloat = 60
    var time = 3.0
    var body: some View {
        ZStack {
            ZStack {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.system(size: 90))
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                        Spacer()
                    }

                    
                }
                .padding(.bottom, 10)
                .padding(.leading, 10)
               
                ZStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 20))

                        .foregroundStyle(.orange.opacity(0.6))
                        .frame(width: 20)
                        .symbolEffect(.breathe)
                    
                    Image(systemName: "circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.orange)
                        .frame(width: 15)
                }
                .frame(width: 100, height: 100)
                .padding(.leading, pad)
                .padding(.bottom, pad)
                .rotationEffect(Angle(degrees: angle))
                .zIndex(-1)

            }
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 5).delay(TimeInterval(time))) {
                    angle = 0
                }
                
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 5).delay(TimeInterval(time + 1))) {
                    pad = 50
                   
                }
                
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 5).delay(TimeInterval(time + 1.2))) {
                    pad = 60
                   
                }
            }


        }
        .frame(width: 100, height: 100)
        .clipped()
        .cornerRadius(25)

    }
}


#Preview {
    iconView()
}

