//
//  SettingView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-05.
//

import SwiftUI

struct SettingView: View {
    
    @State private var angle: Double = 0
    var body: some View {
        
        NavigationStack {
            VStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 100))
                    .padding()
                    .rotationEffect(Angle.degrees(angle))
                
                Text("")
                
                Spacer()
            }
            .onAppear {
                withAnimation(.interpolatingSpring(stiffness: 10, damping: 3)) {
                    angle += 180
                }

            }
            .navigationTitle("Preferences")
        }
    }
}

#Preview {
    SettingView()
}
