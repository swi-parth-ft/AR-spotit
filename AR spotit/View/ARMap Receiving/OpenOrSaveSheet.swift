//
//  OpenOrSaveSheet.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import SwiftUI
import CloudKit


struct OpenOrSaveSheet: View {
    var roomName: String
    var assetFileURL: URL
    var sharedRecord: CKRecord
    var onOpen: () -> Void
    var onSave: () -> Void
    var onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        
        
        NavigationStack {
            VStack(alignment: .leading) {
                Spacer()
                if AppState.shared.isViewOnly {
                    Text("Would you like to open now and start exploring or save copy locally?")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                } else {
                    Text("Would you like to open now and start editing or save copy locally?")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.horizontal)
                }
               
              
                
                Button {
                    onOpen()
                } label: {
                    Text(AppState.shared.isViewOnly ? "Start Exploring" : "Open Now and Collaborate")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button {
                    onSave()
                } label: {
                    Text("Save Copy Locally")
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
            .padding(.bottom)
            .navigationTitle("Choose Action")
     
            .toolbar {
          
                
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
