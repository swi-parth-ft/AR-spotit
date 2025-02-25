//
//  RemoveCollabView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-23.
//

import SwiftUI

struct RemoveCollabView: View {
    var roomName: String = "Bedroom"
    var onUncollab: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
               
                Spacer()
                VStack(alignment: .leading) {
                    
               
                    
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        
                        Text("If you have any new items. Please open the AR to sync them before removing collaboration.")
                            .font(.system(.headline, design: .rounded))
                        
                    }
                    
                    
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        
                        Text("Removing collaborators from this shared world will revoke access for all users and cannot be undone. Proceed?")
                        
                            .font(.system(.headline, design: .rounded))
                        
                    }
                    
                }
                
                
                Button {
                    onUncollab()
                    dismiss()
                } label: {
                    Text("Remove Collaboration")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                
                Button {
                 dismiss()

                } label: {
                    Text("Cencel")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary)
                        .cornerRadius(10)
                }
                
            }
            .padding()
            .navigationTitle("Remove Collab")
        }
    }
}

#Preview {
    RemoveCollabView(onUncollab: {
    })
}
