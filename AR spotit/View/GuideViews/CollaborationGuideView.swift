//
//  CollaborationGuideView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import SwiftUI

struct CollaborationGuideView: View {
    var name: String = "Bedroom"
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onTap: () -> Void = { }
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                    .padding()
                Text("Share Collaboration Link")
                    .font(.system(.title, design: .rounded))
                    .bold()
            }
            .padding(.top)

            
            VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 30))
                    .padding(.horizontal)
                    .frame(width: 30)
                Text("iCloud link can be shared with anyone you want to collaborate with; or for public to find items.")
                    .font(.system(.headline, design: .rounded))
                    .frame(alignment: .leading)
                    .padding(.horizontal)
                
            }
            .padding()
                
                HStack(alignment: .top) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("After generating iCloud link, you can share a QR code for public use or for collaboration.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
            
                HStack(alignment: .top) {
                    Image(systemName: "key.icloud.fill")
                        .font(.system(size: 30))
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("You will set a key to do collaboration; anyone with the key can collaborate with your area map.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
            
                HStack(alignment: .top) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("When collaborators adds new items to the map, you can open the AR map and integrate into it and make them available for public to see.")
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
                Text("Start Collaborating")
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
    CollaborationGuideView()
}
