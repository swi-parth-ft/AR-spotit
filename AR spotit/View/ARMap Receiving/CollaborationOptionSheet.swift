//
//  CollaborationOptionSheet.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-20.
//

import SwiftUI

// 1. Create a new SwiftUI view for the collaboration choice sheet.
struct CollaborationOptionSheet: View {
    var roomName: String
    var onCollaborate: () -> Void
    var onViewOnly: () -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isShowigReceivingLinkGuide = false
    @AppStorage("isShowedReceivingLinkGuide") private var isShowedReceivingLinkGuide: Bool = false

    var body: some View {
        NavigationView {
            VStack(alignment: .center) {
                Spacer()
                HStack {
                    Text("Received \(roomName) invitation. You can view and find items in this area.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    Spacer()
                }
              
                Button {
                    onViewOnly()
                } label: {
                    Text("Explore \(roomName)")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.primary.opacity(1))
                        .cornerRadius(10)
                }
                
                
                Text("Are you a collaborator?")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.blue)
                    .onTapGesture {
                        onCollaborate()
                    }
                    .padding()
                
                
            }
            .onAppear {
                if !isShowedReceivingLinkGuide {
                    isShowigReceivingLinkGuide = true
                    isShowedReceivingLinkGuide = true
                }
            }
            .padding()
            .sheet(isPresented: $isShowigReceivingLinkGuide) {
                ReceivingLinkGuide()
            }
            .navigationTitle("Open \(roomName) Map")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowigReceivingLinkGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        

                        onCancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                }
                
            }
        }
    }
}

#Preview {
    CollaborationOptionSheet(roomName: "Bedroom", onCollaborate: {
    }, onViewOnly: {
        
    }, onCancel: {
        
    } )
}
