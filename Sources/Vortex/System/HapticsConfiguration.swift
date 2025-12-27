//
// HapticsConfiguration.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import Foundation

#if canImport(Haptica)
import Haptica
#endif

/// Configuration for haptic feedback in particle systems.
public struct HapticsConfiguration: Codable, Equatable {
    /// When haptics should be triggered.
    public enum Trigger: String, Codable {
        /// Trigger haptics when particles are created (birth).
        case onBirth
        /// Trigger haptics when particles are destroyed (death).
        case onDeath
        /// Trigger haptics when a burst is triggered.
        case onBurst
        /// Never trigger haptics.
        case never
    }
    
    /// The type of haptic feedback to use.
    public enum HapticType: String, Codable {
        /// Light impact feedback.
        case light
        /// Medium impact feedback.
        case medium
        /// Heavy impact feedback.
        case heavy
        /// Soft impact feedback.
        case soft
        /// Rigid impact feedback.
        case rigid
        /// Success notification feedback.
        case success
        /// Warning notification feedback.
        case warning
        /// Error notification feedback.
        case error
        /// Selection feedback.
        case selection
    }
    
    enum CodingKeys: CodingKey {
        case trigger, type, intensity, minimumInterval
    }
    
    /// When haptics should be triggered. Defaults to `.never`.
    public var trigger: Trigger
    
    /// The type of haptic feedback. Defaults to `.medium`.
    public var type: HapticType
    
    /// The intensity/strength of the haptic feedback (0.0 to 1.0). Defaults to 1.0.
    public var intensity: Double
    
    /// The minimum time interval between haptic triggers (in seconds). Defaults to 0.1.
    /// This prevents haptics from firing too frequently.
    public var minimumInterval: TimeInterval
    
    /// The last time haptics were triggered.
    private var lastHapticTime: TimeInterval
    
    /// Creates a new haptics configuration.
    /// - Parameters:
    ///   - trigger: When haptics should be triggered. Defaults to `.never`.
    ///   - type: The type of haptic feedback. Defaults to `.medium`.
    ///   - intensity: The intensity/strength of the haptic feedback (0.0 to 1.0). Defaults to 1.0.
    ///   - minimumInterval: The minimum time interval between haptic triggers (in seconds). Defaults to 0.1.
    public init(
        trigger: Trigger = .never,
        type: HapticType = .medium,
        intensity: Double = 1.0,
        minimumInterval: TimeInterval = 0.1
    ) {
        self.trigger = trigger
        self.type = type
        self.intensity = max(0.0, min(1.0, intensity))
        self.minimumInterval = minimumInterval
        self.lastHapticTime = 0
    }
    
    /// Internal method to check if haptics should be triggered and update the last trigger time.
    mutating func shouldTrigger(at time: TimeInterval) -> Bool {
        guard trigger != .never else { return false }
        
        let timeSinceLastHaptic = time - lastHapticTime
        guard timeSinceLastHaptic >= minimumInterval else { return false }
        
        lastHapticTime = time
        return true
    }
    
    /// Resets the last haptic time to allow immediate triggering.
    mutating func reset() {
        lastHapticTime = 0
    }
    
    /// Custom Codable implementation to exclude lastHapticTime from encoding/decoding.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trigger = try container.decode(Trigger.self, forKey: .trigger)
        type = try container.decode(HapticType.self, forKey: .type)
        intensity = try container.decode(Double.self, forKey: .intensity)
        minimumInterval = try container.decode(TimeInterval.self, forKey: .minimumInterval)
        lastHapticTime = 0
    }
    
    /// Custom Codable implementation to exclude lastHapticTime from encoding.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trigger, forKey: .trigger)
        try container.encode(type, forKey: .type)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(minimumInterval, forKey: .minimumInterval)
    }
}

extension HapticsConfiguration {
    /// Equatable conformance - compares only configuration values, not internal state.
    public static func == (lhs: HapticsConfiguration, rhs: HapticsConfiguration) -> Bool {
        lhs.trigger == rhs.trigger &&
        lhs.type == rhs.type &&
        lhs.intensity == rhs.intensity &&
        lhs.minimumInterval == rhs.minimumInterval
    }
    
    /// Default haptics configuration (disabled).
    public static let `default` = HapticsConfiguration(trigger: .never)
    
    /// Convenience initializer for burst-triggered haptics.
    public static func burst(type: HapticType = .medium, intensity: Double = 1.0) -> HapticsConfiguration {
        HapticsConfiguration(trigger: .onBurst, type: type, intensity: intensity)
    }
    
    /// Convenience initializer for birth-triggered haptics.
    public static func onBirth(type: HapticType = .light, intensity: Double = 0.5) -> HapticsConfiguration {
        HapticsConfiguration(trigger: .onBirth, type: type, intensity: intensity, minimumInterval: 0.05)
    }
    
    /// Convenience initializer for death-triggered haptics.
    public static func onDeath(type: HapticType = .light, intensity: Double = 0.3) -> HapticsConfiguration {
        HapticsConfiguration(trigger: .onDeath, type: type, intensity: intensity, minimumInterval: 0.05)
    }
}

