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
                    Circle()
                        .fill(.orange.opacity(0.6))
                        .frame(width: 20)
                    
                    Circle()
                        .fill(.orange)
                        .frame(width: 15)
                }
                .frame(width: 100, height: 100)
                .padding(.leading, 60)
                .padding(.bottom, 60)
                .rotationEffect(Angle(degrees: angle))
                .zIndex(-1)

            }
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 100, damping: 5).delay(4)) {
                    angle = 0
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

