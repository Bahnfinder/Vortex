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
    
    public init(text: String, fontSize: CGFloat = 40) {
        self.text = text
        self.fontSize = fontSize
        
        // 1. Rakete (fliegt hoch)
        let rocket = VortexSystem(
            tags: ["circle"],
            position: [0.5, 1.0],
            birthRate: 0,
            emissionLimit: 1,
            lifespan: 1.2,
            speed: 1.2,
            angle: .degrees(180),
            colors: .single(.white),
            size: 0.3,
            stretchFactor: 4
        )
        
        let trail = VortexSystem(
            tags: ["circle"],
            spawnOccasion: .onUpdate,
            emissionLimit: nil,
            lifespan: 0.3,
            speed: 0.1,
            colors: .ramp(.white, .yellow, .clear),
            size: 0.1
        )
        rocket.secondarySystems = [trail]
        
        _rocketSystem = State(initialValue: rocket)
        
        // 2. Text-Explosion
        let textSys = VortexSystem(
            tags: ["circle"],
            birthRate: 0,
            lifespan: 4.0, // Länger sichtbar
            speed: 0,
            colors: .randomRamp(
                [.white, .yellow, .orange, .clear],
                [.white, .blue, .purple, .clear],
                [.white, .pink, .red, .clear],
                [.white, .green, .cyan, .clear]
            ),
            size: 0.3,
            haptics: .burst(type: .heavy, intensity: 1.0)
        )
        _textSystem = State(initialValue: textSys)
    }
    
    public var body: some View {
        ZStack {
            // Hintergrund schwarz für besseren Kontrast
            Color.black.ignoresSafeArea()
            
            // Rakete
            VortexView(rocketSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 32)
                    .tag("circle")
                    .blur(radius: 2)
            }
            
            // Explosion
            VortexView(textSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 12) // Etwas kleiner für mehr Detail
                    .tag("circle")
                    .blur(radius: 1)
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true
            
            // Sequenz starten
            rocketSystem.burst()
            
            // Explosion timen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                explodeText()
            }
        }
    }
    
    private func explodeText() {
        // Berechne Punkte im Hintergrund, um UI nicht zu blockieren
        DispatchQueue.global(qos: .userInitiated).async {
            let points = TextRasterizer.rasterize(text: self.text, fontSize: self.fontSize * 2.5) // Höhere Auflösung
            
            DispatchQueue.main.async {
                print("Vortex: Spawning \(points.count) particles for text")
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
        
        // Safety Limit für Partikel
        let maxParticles = 4000
        let step = max(1, points.count / maxParticles)
        
        for (i, point) in points.enumerated() where i % step == 0 {
            let particle = Particle(
                tag: tags.randomElement() ?? "circle",
                position: SIMD2(Double(point.x), Double(point.y)),
                speed: [Double.random(in: -0.01...0.01), Double.random(in: -0.01...0.01)],
                birthTime: currentTime + Double.random(in: 0...0.1), // Leicht versetztes Erscheinen
                lifespan: lifespan + Double.random(in: -0.5...0.5),
                initialSize: size * Double.random(in: 0.6...1.4),
                angularSpeed: [0,0,0],
                colors: getNewParticleColorRamp()
            )
            particles.append(particle)
        }
        
        // Haptik
        HapticsHelper.trigger(&haptics, at: currentTime)
    }
}

struct TextRasterizer {
    static func rasterize(text: String, fontSize: CGFloat) -> [CGPoint] {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black) // Sehr fetter Font wichtig für Partikel
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        
        let width = Int(ceil(textSize.width))
        let height = Int(ceil(textSize.height))
        
        // 1. Grayscale Context erstellen (1 Byte pro Pixel = Robust & Schnell)
        guard let context = CGContext(
            data: nil, // System soll Speicher verwalten
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0, // System soll optimalen Stride wählen
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue // Nur Helligkeit (Maske)
        ) else { return [] }
        
        // 2. Text weiß auf schwarz zeichnen
        // Koordinatensystem anpassen (CoreGraphics ist Y-flipped im Vergleich zu UIKit Text)
        // Aber für Text Extraction ist es egal, solange wir x,y konsistent lesen.
        // Wir setzen schwarz als Hintergrund
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Text zeichnen
        UIGraphicsPushContext(context)
        attributedString.draw(at: .zero) // Zeichnet weiß
        UIGraphicsPopContext()
        
        // 3. Pixel lesen
        guard let data = context.data else { return [] }
        
        var points: [CGPoint] = []
        
        // Zentrierung im Ziel-System
        let targetCenterX = 0.5
        let targetCenterY = 0.3
        let scale = 0.85 / Double(width)
        
        let textPixels = Double(width * height) * 0.25
        let targetCount = 2500.0
        let sampleStep = max(1, Int(sqrt(textPixels / targetCount)))
        
        // Use UnsafeBufferPointer for safe iteration without copy
        let buffer = UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: height * bytesPerRow), count: height * bytesPerRow)
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x
                // Check bounds just in case
                if offset < buffer.count {
                    let brightness = buffer[offset]
                    
                    if brightness > 50 {
                        let relX = (Double(x) - Double(width) / 2.0)
                        let relY = (Double(y) - Double(height) / 2.0)
                        
                        let finalX = targetCenterX + (relX * scale)
                        let finalY = targetCenterY + (relY * scale)
                        
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
