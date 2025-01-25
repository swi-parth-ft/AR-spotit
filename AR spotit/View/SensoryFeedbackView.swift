//
//  SensoryFeedbackView.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-01-24.
//


import SwiftUI
import UIKit

struct SensoryFeedbackView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Sensory Feedback Buttons")
                        .font(.largeTitle)
                        .padding(.top, 40)
                    
                    // Haptic Impact Feedbacks
                    Group {
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                        }) {
                            Text("Light Impact")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                        }) {
                            Text("Medium Impact")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .heavy)
                        }) {
                            Text("Heavy Impact")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Haptic Notification Feedbacks
                    Group {
                        Button(action: {
                            HapticManager.shared.notification(type: .success)
                        }) {
                            Text("Success Notification")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.teal)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                               HapticManager.shared.notification(type: .warning)
                        }) {
                            Text("Warning Notification")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            HapticManager.shared.notification(type: .error)
                        }) {
                            Text("Error Notification")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            HapticManager.shared.notification(type: .error)
                        }) {
                            Text("Error Notification")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(8)
                        }
                        
                    
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Haptic Feedback", displayMode: .inline)
        }
    }
}

// Haptic Manager to handle different types of haptic feedback


struct SensoryFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        SensoryFeedbackView()
    }
}
