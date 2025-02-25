//
//  DeleteConfirm.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-20.
//

import SwiftUI

struct DeleteConfirm: View {
    var isCollab: Bool = false
    var roomName: String = "Bedroom"
    var onDelete: (String) -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
               
                Spacer()
                if isCollab {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            
                            Text("Deleting this shared world will revoke access for all users and cannot be undone. Proceed?")

                                .font(.system(.headline, design: .rounded))
                            
                        }
            
                     
                    }
                } else {
                    Text("Are you sure you want to \(Text("Delete").foregroundStyle(.red)) \(roomName)? This action can not be undone.")
                        .font(.headline)
                        .bold()
                        .padding(.bottom)
                }
                
                Button {
                    onDelete(roomName)
                    dismiss()
                } label: {
                    Text("Delete")
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
            .navigationTitle("Delete \(roomName)")
        }
    }
}

#Preview {
    DeleteConfirm(onDelete: {_ in 
        
    })
}
