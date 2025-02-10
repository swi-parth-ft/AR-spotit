//
//  HostingWindowFinder.swift
//  AR spotit
//
//  Created by Parth Antala on 2025-02-09.
//


import SwiftUI

extension View {
    /// Injects a callback that provides the hosting UIWindow.
    func withHostingWindow(_ callback: @escaping (UIWindow?) -> Void) -> some View {
        background(HostingWindowFinder(callback: callback))
    }
}

struct HostingWindowFinder: UIViewRepresentable {
    let callback: (UIWindow?) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { }
}