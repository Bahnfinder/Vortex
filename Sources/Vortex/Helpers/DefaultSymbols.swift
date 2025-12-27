//
// DefaultSymbols.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI

// Helper to find the bundle logic since Bundle.module might be missing during some build phases
private class BundleFinder {}

extension Foundation.Bundle {
    static var currentModule: Bundle = {
        // Fallback strategy to ensure build succeeds
        let bundleName = "Vortex_Vortex"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL
        ]
        
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        
        return Bundle(for: BundleFinder.self)
    }()
}

/// Set up static variables for  images(symbols) in the asset catalog contained within the Resources folder
extension Image {
    public static let circle = Image("circle", bundle: .currentModule)
    public static let confetti = Image("confetti", bundle: .currentModule)
    public static let sparkle = Image("sparkle", bundle: .currentModule)
}
