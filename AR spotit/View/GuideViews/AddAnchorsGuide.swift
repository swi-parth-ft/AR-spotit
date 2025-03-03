//
//  CollaborationGuideView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import SwiftUI

struct AddAnchorsGuide: View {
   
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
var onTap: () -> Void = { }
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "circle.badge.plus.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse)
                    .padding()
                Text("Add an Item")
                    .font(.system(.title, design: .rounded))
                    .bold()
            }
            .padding(.top)

            
            VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 30))
                    .padding(.horizontal)
                    .frame(width: 30)
                Text("Tap on the real world object you want to mark and save its position.")
                    .font(.system(.headline, design: .rounded))
                    .frame(alignment: .leading)
                    .padding(.horizontal)
                
            }
            .padding()
                
                HStack(alignment: .top) {
                    Image(systemName: "hand.rays.fill")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("Tap and hold the items you placed to rename, delete or change their position.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
            
             
            
               
                
        }
            .padding()
            Spacer()
            Button {
                onTap()
                dismiss()
            } label: {
                Text("Add Item")
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
    AddAnchorsGuide()
}
