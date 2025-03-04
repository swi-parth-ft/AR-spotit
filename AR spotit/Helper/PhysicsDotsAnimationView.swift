//
//  PhysicsDotsAnimationView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-24.
//


import SwiftUI
import AnimateText

struct PhysicsDotsAnimationView: View {
    
    @State private var text: String = ""
    var body: some View {
        ZStack {
            
            Color.primary.colorInvert()
            
            VStack {
                iconView(time: 0)
                AnimateText<ATOffsetEffect>($text)
                    .font(.system(size: 70, design: .rounded))
                    .bold()
                
            }
            .onAppear {
                text = "it's here."
            }
        }
        .ignoresSafeArea()
    }
    
    
}

struct PhysicsDotsAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        PhysicsDotsAnimationView()
    }
}

