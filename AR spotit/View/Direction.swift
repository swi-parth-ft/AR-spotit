//
//  Direction.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-24.
//


enum Direction {
    case inFront
    case onRight
    case onLeft
    case behindYou

    static func classify(angle: Double) -> String {
        switch angle {
        case -30...30:
            return "In Front"
        case -160..<(-30):
            return "On Right"
        case 30...160:
            return "On Left"
        default: // Covers angles less than -160 or greater than 160
            return "Behind You"
        }
    }
}