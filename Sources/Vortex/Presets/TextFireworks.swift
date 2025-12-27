//
// TextFireworks.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI

extension VortexSystem {
    /// Creates a simple text fireworks effect by creating explosion systems for each letter.
    /// Each letter explodes sequentially with a delay.
    /// 
    /// **Note:** This is a simplified version that creates explosions in a line.
    /// For actual text shape, you'd need to render text and extract pixel positions.
    /// 
    /// - Parameters:
    ///   - text: The text to display (each character gets an explosion).
    ///   - letterSpacing: Spacing between letters (in unit space, 0.0-1.0). Defaults to 0.08.
    ///   - startX: Starting X position for first letter. Defaults to 0.2.
    ///   - startY: Y position for all letters. Defaults to 0.5.
    ///   - delayBetweenLetters: Delay between each letter exploding (in seconds). Defaults to 0.15.
    /// - Returns: An array of VortexSystem instances, one for each character.
    public static func textFireworks(
        _ text: String,
        letterSpacing: Double = 0.08,
        startX: Double = 0.2,
        startY: Double = 0.5,
        delayBetweenLetters: TimeInterval = 0.15
    ) -> [VortexSystem] {
        let characters = Array(text.uppercased())
        var systems: [VortexSystem] = []
        var letterIndex = 0 // Track actual letter position (excluding spaces)
        
        for (index, char) in characters.enumerated() {
            // Skip spaces but still account for them in spacing
            if char == " " {
                continue
            }
            
            let xPosition = startX + (Double(letterIndex) * letterSpacing)
            letterIndex += 1
            
            // Create explosion system for this letter position
            let explosion = VortexSystem(
                tags: ["circle"],
                position: [xPosition, startY],
                birthRate: 0, // Don't auto-emit
                burstCount: 200,
                burstCountVariation: 50,
                lifespan: 2.0,
                speed: 0.5,
                speedVariation: 1.0,
                angleRange: .degrees(360),
                acceleration: [0, 1.5],
                dampingFactor: 4,
                colors: .randomRamp(
                    [.white, .pink, .pink],
                    [.white, .blue, .blue],
                    [.white, .green, .green],
                    [.white, .orange, .orange],
                    [.white, .cyan, .cyan],
                    [.white, .yellow, .yellow]
                ),
                size: 0.15,
                sizeVariation: 0.1,
                sizeMultiplierAtDeath: 0,
                startTimeOffset: Double(letterIndex - 1) * delayBetweenLetters,
                haptics: .burst(type: .heavy, intensity: 0.8)
            )
            
            systems.append(explosion)
        }
        
        return systems
    }
}

/// A view that displays multiple Vortex systems (for text fireworks).
public struct MultiVortexView<Symbols>: View where Symbols: View {
    let systems: [VortexSystem]
    let symbols: Symbols
    let targetFrameRate: Int
    @State private var startTime: Date?
    
    public init(
        systems: [VortexSystem],
        targetFrameRate: Int = 60,
        @ViewBuilder symbols: () -> Symbols
    ) {
        self.systems = systems
        self.targetFrameRate = targetFrameRate
        self.symbols = symbols()
    }
    
    public var body: some View {
        ZStack {
            ForEach(systems) { system in
                VortexView(system, targetFrameRate: targetFrameRate) {
                    symbols
                }
            }
        }
        .onAppear {
            startTime = Date()
            // Trigger bursts for all systems based on their startTimeOffset
            for system in systems {
                let delay = system.startTimeOffset
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        system.burst()
                    }
                } else {
                    // Immediate burst
                    system.burst()
                }
            }
        }
    }
}
