//
//  SortingIcon.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//

import SwiftUI


struct SortingIcon: View {
    let mainIcon: String
    let showArrow: Bool
    let ascending: Bool
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: mainIcon)
                .font(.system(size: 24))
                .frame(width: 24, height: 24)
            if showArrow {
                Image(systemName: ascending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .offset(x: 4, y: 4)
            }
        }
    }
}
