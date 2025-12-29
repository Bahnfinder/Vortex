//
// VortexView+Haptics.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI

extension VortexView {
    /// Enables haptic feedback for this particle system with a simple API.
    /// - Parameters:
    ///   - trigger: When haptics should be triggered. Use `.onBurst` for confetti-like effects,
    ///     `.onExplosion` for explosions (like fireworks - triggers only when secondary systems spawn),
    ///     `.onDeath` for individual particle deaths, or `.onBirth` for continuous effects.
    ///   - type: The type of haptic feedback. Defaults to `.medium`.
    ///   - intensity: The intensity/strength of the haptic feedback (0.0 to 1.0). Defaults to 1.0.
    /// - Returns: A modified VortexView with haptics enabled.
    public func haptics(
        _ trigger: HapticsConfiguration.Trigger = .onBurst,
        type: HapticsConfiguration.HapticType = .medium,
        intensity: Double = 1.0
    ) -> some View {
        self.modifier(HapticsModifier(trigger: trigger, type: type, intensity: intensity))
    }
    
    /// Convenience method for common haptic patterns.
    /// - Parameter strength: The strength of haptics: `.light`, `.medium`, or `.heavy`.
    /// - Returns: A modified VortexView with haptics enabled for bursts.
    public func haptics(_ strength: HapticsStrength) -> some View {
        let (type, intensity) = strength.hapticConfig
        return haptics(.onBurst, type: type, intensity: intensity)
    }
}

/// Simple haptic strength options for easy use.
public enum HapticsStrength {
    case light
    case medium
    case heavy
    
    var hapticConfig: (HapticsConfiguration.HapticType, Double) {
        switch self {
        case .light:
            return (.light, 0.5)
        case .medium:
            return (.medium, 1.0)
        case .heavy:
            return (.heavy, 1.0)
        }
    }
}

/// Internal modifier that applies haptics configuration to a VortexView.
private struct HapticsModifier: ViewModifier {
    let trigger: HapticsConfiguration.Trigger
    let type: HapticsConfiguration.HapticType
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(VortexSystemPreferenceKey.self) { system in
                system?.haptics = HapticsConfiguration(
                    trigger: trigger,
                    type: type,
                    intensity: intensity
                )
            }
    }
}

