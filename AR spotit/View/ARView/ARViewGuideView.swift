//
//  CollaborationGuideView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import SwiftUI

struct ARViewGuideView: View {
    var name: String = "Bedroom"
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onTap: () -> Void = { }
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "arkit")
                    .font(.system(size: 80))
                    .symbolEffect(.pulse)
                    .padding()
                Text("Scanning Area Tips")
                    .font(.system(.title, design: .rounded))
                    .bold()
            }
            .padding(.bottom)
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 30))
                            .padding(.horizontal)
                            .frame(width: 30)
                        Text("While creating a new area map, move and scan slowly in all directions and angles to ensure you capture all the relevant points of interest in your area.")
                            .font(.system(.headline, design: .rounded))
                            .frame(alignment: .leading)
                            .padding(.horizontal)
                        
                    }
                    .padding()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 30))
                            .padding(.horizontal)
                            .frame(width: 30)
                        Text("Ensure the room is well-lit for accurate scanning. Avoid shadows or overly bright spots.")
                            .font(.system(.headline, design: .rounded))
                            .frame(alignment: .leading)
                            .padding(.horizontal)
                        
                    }
                    .padding()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "rectangle.3.offgrid.fill")
                            .font(.system(size: 30))
                            .padding(.horizontal)
                            .frame(width: 30)
                        Text("Scan walls, corners, and the floor. Aim to cover 60-70% of the area with the white mesh.")
                            .font(.system(.headline, design: .rounded))
                            .frame(alignment: .leading)
                            .padding(.horizontal)
                        
                    }
                    .padding()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .padding(.horizontal)
                            .frame(width: 30)
                        Text("You can add items while scanning by tapping \(Image(systemName: "plus.circle")); adding items after scanning area is recommended.")
                            .font(.system(.headline, design: .rounded))
                            .frame(alignment: .leading)
                            .padding(.horizontal)
                        
                    }
                    .padding()
                    
                }
                .padding()
            }
            Button {
                onTap()
                dismiss()
            } label: {
                Text("Start Scanning")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(Color.primary.opacity(1))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    ARViewGuideView()
}
