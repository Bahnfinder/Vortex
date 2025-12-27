//
// TextFireworks.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// A view that displays a firework which explodes into text.
public struct TextFireworksView: View {
    let text: String
    let fontSize: CGFloat
    
    @State private var rocketSystem: VortexSystem
    @State private var textSystem: VortexSystem
    @State private var hasTriggered = false
    
    // Rakete fliegt 1.0s
    let flightDuration = 1.0
    
    public init(text: String, fontSize: CGFloat = 40) {
        self.text = text
        self.fontSize = fontSize
        
        // 1. Rakete (fliegt hoch)
        // Orientiert am Original 'Fireworks.swift' Preset
        let rocket = VortexSystem(
            tags: ["circle"],
            position: [0.5, 1.0], 
            shape: .box(width: 1.0, height: 0), // Breit verteilt
            birthRate: 0,
            emissionLimit: nil,
            burstCount: 10,
            lifespan: flightDuration,
            speed: 1.5,
            speedVariation: 0.5, // Variation für Natürlichkeit
            angle: .zero, // Nach oben
            angleRange: .degrees(15), // Leicht gefächert
            dampingFactor: 2, // WICHTIG: Bremst die Rakete ab, wie im Original!
            colors: .single(.white), // Original ist WEISS (nicht bunt)
            size: 0.15, // Original Größe (war 0.2)
            stretchFactor: 4 // Original Stretch (war 6)
        )
        
        // Funkel-Schweif (Exakt wie Original Fireworks)
        let sparkles = VortexSystem(
            tags: ["circle"],
            spawnOccasion: .onUpdate,
            emissionLimit: 1,
            lifespan: 0.5,
            speed: 0.05,
            angleRange: .degrees(90),
            size: 0.05
        )
        rocket.secondarySystems = [sparkles]
        
        _rocketSystem = State(initialValue: rocket)
        
        // 2. Text-Explosion
        // Optimiert für Performance und Lesbarkeit
        let textSys = VortexSystem(
            tags: ["circle"],
            birthRate: 0,
            lifespan: 8.0, // Sehr lange sichtbar
            speed: 0.001, // Praktisch keine Bewegung, damit Text scharf bleibt
            speedVariation: 0,
            acceleration: [0, 0], // KEINE Schwerkraft, Text soll schweben
            dampingFactor: 0,
            colors: .randomRamp(
                // Lange Plateau-Phasen für volle Sichtbarkeit
                [.white, .pink, .pink, .pink, .pink, .clear],
                [.white, .blue, .blue, .blue, .blue, .clear],
                [.white, .green, .green, .green, .green, .clear],
                [.white, .orange, .orange, .orange, .orange, .clear],
                [.white, .cyan, .cyan, .cyan, .cyan, .clear],
                [.white, .yellow, .yellow, .yellow, .yellow, .clear]
            ),
            size: 0.25, // Kleiner für mehr Schärfe (war 0.35)
            sizeMultiplierAtDeath: 0.5,
            haptics: .burst(type: .heavy, intensity: 1.0)
        )
        _textSystem = State(initialValue: textSys)
    }
    
    public var body: some View {
        ZStack {
            // Rakete
            VortexView(rocketSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 32)
                    .tag("circle")
                    .blur(radius: 2)
                    .blendMode(.plusLighter)
            }
            
            // Explosion
            VortexView(textSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 10)
                    .tag("circle")
                    .blur(radius: 1)
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true
            
            rocketSystem.burst()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration) {
                explodeText()
            }
        }
    }
    
    private func explodeText() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Font Size 2.0x für gute Auflösung
            let points = TextRasterizer.rasterize(text: self.text, fontSize: self.fontSize * 2.0)
            
            DispatchQueue.main.async {
                self.textSystem.spawnAt(points: points)
            }
        }
    }
}

// MARK: - Helper

extension VortexSystem {
    func spawnAt(points: [CGPoint]) {
        self.isActive = true
        self.isEmitting = true
        
        let currentTime = Date().timeIntervalSince1970
        // Erhöht für Schärfe (1200 statt 800)
        let maxParticles = 1200 
        let step = max(1, points.count / maxParticles)
        
        for (i, point) in points.enumerated() where i % step == 0 {
            // Organisches "Aufblühen": Partikel spawnen über 0.6s verteilt
            // Das reduziert auch den CPU-Spike beim ersten Frame
            let spawnDelay = Double.random(in: 0...0.6)
            
            let particle = Particle(
                tag: tags.randomElement() ?? "circle",
                position: SIMD2(Double(point.x), Double(point.y)),
                speed: [0, 0],
                birthTime: currentTime + spawnDelay, 
                lifespan: lifespan + Double.random(in: -1.0...1.0),
                initialSize: size * Double.random(in: 0.8...1.2),
                angularSpeed: [0,0,0],
                colors: getNewParticleColorRamp()
            )
            particles.append(particle)
        }
        
        HapticsHelper.trigger(&haptics, at: currentTime)
    }
}

struct TextRasterizer {
    static func rasterize(text: String, fontSize: CGFloat) -> [CGPoint] {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white] // Weißer Text
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        let width = Int(ceil(textSize.width))
        let height = Int(ceil(textSize.height))
        
        // RGBA Context (Sicher & Robust)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Wir lassen CoreGraphics den Speicher verwalten (data: nil)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        // Hintergrund transparent (Standard bei neuem Context) oder explizit schwarz löschen?
        // Wir wollen nur den Text (weiß) auf transparentem Hintergrund.
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Text zeichnen
        UIGraphicsPushContext(context)
        attributedString.draw(at: .zero)
        UIGraphicsPopContext()
        
        guard let data = context.data else { return [] }
        
        var points: [CGPoint] = []
        
        // Ziel-Position (Oben, wo Rakete explodiert)
        let targetCenterX = 0.5
        let targetCenterY = 0.25 
        
        // Skalierung: Text passt in 85% Breite
        let scale = 0.85 / Double(width)
        
        // Adaptive Sampling
        let textPixels = Double(width * height) * 0.25
        let targetCount = 3000.0
        let sampleStep = max(1, Int(sqrt(textPixels / targetCount)))
        
        let buffer = UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: height * bytesPerRow), count: height * bytesPerRow)
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                // Wir prüfen Alpha (letztes Byte bei RGBA) oder Rot (erstes Byte, da Text weiß ist)
                // Bei Weiß (255, 255, 255, 255) ist alles > 0.
                if offset + 3 < buffer.count {
                    let alpha = buffer[offset + 3]
                    
                    if alpha > 50 {
                        let relX = (Double(x) - Double(width) / 2.0)
                        let relY = (Double(y) - Double(height) / 2.0)
                        
                        // Y-Flip für korrekte Ausrichtung
                        let finalX = targetCenterX + (relX * scale)
                        let finalY = targetCenterY - (relY * scale)
                        
                        points.append(CGPoint(x: finalX, y: finalY))
                    }
                }
            }
        }
        
        return points
        #else
        return []
        #endif
    }
}
