//
// View+Extensions.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI

public enum SafeBlendMode {
    case plusLighterIfAvailable
}

public extension View {
    @ViewBuilder
    func safeBlendMode(_ mode: SafeBlendMode) -> some View {
        switch mode {
        case .plusLighterIfAvailable:
            if #available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *) {
                self.blendMode(.plusLighter)
            } else {
                self.blendMode(.screen)
            }
        }
    }
}
