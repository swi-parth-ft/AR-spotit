//
//  CollaborationGuideView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import SwiftUI

struct ReceivingLinkGuide: View {
    var name: String = "Bedroom"
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onTap: () -> Void = { }
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "link.icloud.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                    .padding()
                Text("Recived iCloud Link")
                    .font(.system(.title, design: .rounded))
                    .bold()
            }
            .padding(.top)

            
            VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: "eyes")
                    .font(.system(size: 30))
                    .padding(.horizontal)
                    .frame(width: 30)
                Text("You can look and find items in the area map with AR or explore whole map with every item in it.")
                    .font(.system(.headline, design: .rounded))
                    .frame(alignment: .leading)
                    .padding(.horizontal)
                
            }
            .padding()
                
               
            
                HStack(alignment: .top) {
                    Image(systemName: "sharedwithyou")
                        .font(.system(size: 30))
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("If you have the Key for the map you can choose to collaborate and add items in it.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
            
                HStack(alignment: .top) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 30))
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("You can save the received map locally for your personal use.")
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
                Text("Next")
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

#Preview {
    ReceivingLinkGuide()
}
