//
//  ParticleView 2.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-11.
//


import SwiftUI
import UIKit

struct ParticleTextView: View {
    
    @State private var text : String = "a"
    @FocusState private var onfocus: Bool
    
    
    var body: some View {
        
        ZStack{
            VStack {
                ParticleTextAnimation(text: text)
                    .ignoresSafeArea()
                    .opacity(onfocus ? 0.3 : 1)
            }
           

        }
    }
}



#Preview {
    ParticleTextView()
}
