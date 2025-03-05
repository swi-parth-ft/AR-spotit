//
//  CollaborationGuideView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-03-01.
//

import SwiftUI

struct FindItemGuide: View {
   
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
var onTap: () -> Void = { }
    var body: some View {
        VStack {
            VStack {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 80))
                    .foregroundStyle(.primary)
                    .symbolEffect(.pulse)
                    .padding()
                Text("Finding an Item")
                    .font(.system(.title, design: .rounded))
                    .bold()
            }
            .padding(.top)

            
            VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 30))
                    .padding(.horizontal)
                    .frame(width: 30)
                Text("When you click on any item to find, you will feel dynamic haptic feedback; higher the frequency, Closer the item is.")
                    .font(.system(.headline, design: .rounded))
                    .frame(alignment: .leading)
                    .padding(.horizontal)
                
            }
            .padding()
                
                HStack(alignment: .top) {
                    Image(systemName: "airpodspro")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("Tap on the \(Image(systemName: "speaker.2")) to hear audio feedback; Wearing the AirPods is recommended to hear spatial audio coming from the item.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
                
                HStack(alignment: .top) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("You can look up a specific item by searching for it in the list when you are exploring entire map.")
                        .font(.system(.headline, design: .rounded))
                        .frame(alignment: .leading)
                        .padding(.horizontal)
                    
                }
                .padding()
                
                
                HStack(alignment: .top) {
                    Image(systemName: "circle.hexagongrid")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.horizontal)
                        .frame(width: 30)
                    Text("While you searching an item, you can switch between finding item and seeing all items on the map.")
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
                Text("Start Exploring")
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
    FindItemGuide()
}
