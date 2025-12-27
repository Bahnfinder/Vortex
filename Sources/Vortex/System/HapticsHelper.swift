//
// HapticsHelper.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import Foundation

#if canImport(Haptica)
import Haptica
#endif

/// Helper class for triggering haptic feedback using Haptica.
enum HapticsHelper {
    /// Triggers haptic feedback based on the configuration.
    /// - Parameters:
    ///   - configuration: The haptics configuration to use.
    ///   - currentTime: The current time interval.
    static func trigger(_ configuration: inout HapticsConfiguration, at currentTime: TimeInterval) {
        #if canImport(Haptica) && os(iOS)
        guard configuration.shouldTrigger(at: currentTime) else { return }
        
        let haptic: Haptic
        
        switch configuration.type {
        case .light:
            haptic = .impact(.light)
        case .medium:
            haptic = .impact(.medium)
        case .heavy:
            haptic = .impact(.heavy)
        case .soft:
            haptic = .impact(.soft)
        case .rigid:
            haptic = .impact(.rigid)
        case .success:
            haptic = .notification(.success)
        case .warning:
            haptic = .notification(.warning)
        case .error:
            haptic = .notification(.error)
        case .selection:
            haptic = .selection
        }
        
        // Note: Haptica doesn't directly support intensity, but we can
        // use different impact types or trigger multiple times for stronger effects.
        // For now, we'll just trigger the haptic as configured.
        haptic.generate()
        #endif
    }
}

