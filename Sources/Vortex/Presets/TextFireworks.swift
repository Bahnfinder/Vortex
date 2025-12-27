//
// TextFireworks.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension VortexSystem {
    /// Creates a text fireworks effect where fireworks shoot up and explode.
    /// Each letter gets its own firework that launches from the bottom and explodes at the top.
    /// 
    /// - Parameters:
    ///   - text: The text to display.
    ///   - letterSpacing: Spacing between letters (in unit space). Defaults to 0.08.
    ///   - startY: Starting Y position for fireworks (bottom). Defaults to 0.9.
    ///   - explosionY: Y position where explosions happen (top). Defaults to 0.2.
    ///   - delayBetweenLetters: Delay between each letter launching (in seconds). Defaults to 0.2.
    /// - Returns: An array of VortexSystem instances, one for each character.
    public static func textFireworks(
        _ text: String,
        letterSpacing: Double = 0.08,
        startY: Double = 0.9,
        explosionY: Double = 0.2,
        delayBetweenLetters: TimeInterval = 0.2
    ) -> [VortexSystem] {
        let characters = Array(text.uppercased())
        var systems: [VortexSystem] = []
        var letterIndex = 0
        
        // Calculate approximate letter positions
        let totalWidth = Double(characters.filter { $0 != " " }.count) * letterSpacing
        let startX = (1.0 - totalWidth) / 2.0
        
        for char in characters {
            if char == " " {
                continue
            }
            
            let xPosition = startX + (Double(letterIndex) * letterSpacing)
            letterIndex += 1
            
            // Create sparkles that follow the launcher (like in .fireworks)
            let sparkles = VortexSystem(
                tags: ["circle"],
                spawnOccasion: .onUpdate,
                emissionLimit: 1,
                lifespan: 0.5,
                speed: 0.05,
                angleRange: .degrees(90),
                size: 0.05
            )
            
            // Create the explosion (like in .fireworks)
            let explosion = VortexSystem(
                tags: ["circle"],
                spawnOccasion: .onDeath,
                position: [xPosition, explosionY],
                birthRate: 100_000,
                emissionLimit: 500,
                speed: 0.5,
                speedVariation: 1,
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
                sizeMultiplierAtDeath: 0
            )
            
            // Create the launching firework (like the main system in .fireworks)
            let launcher = VortexSystem(
                tags: ["circle"],
                secondarySystems: [sparkles, explosion],
                position: [xPosition, startY],
                birthRate: 0, // Don't auto-emit
                emissionLimit: 1,
                lifespan: 1.0,
                speed: 1.5,
                speedVariation: 0.3,
                angle: .degrees(-90), // Shoot up
                angleRange: .degrees(10),
                dampingFactor: 2,
                size: 0.15,
                stretchFactor: 4,
                startTimeOffset: Double(letterIndex - 1) * delayBetweenLetters,
                haptics: .onDeath(type: .heavy, intensity: 1.0)
            )
            
            systems.append(launcher)
        }
        
        return systems
    }
}

/// A view that displays multiple Vortex systems (for text fireworks).
public struct MultiVortexView<Symbols>: View where Symbols: View {
    let systems: [VortexSystem]
    let symbols: Symbols
    let targetFrameRate: Int
    @State private var hasTriggered = false
    
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
            guard !hasTriggered else { return }
            hasTriggered = true
            
            // Trigger launches for all systems based on their startTimeOffset
            for system in systems {
                let delay = system.startTimeOffset
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        system.burst()
                    }
                } else {
                    system.burst()
                }
            }
        }
    }
}
