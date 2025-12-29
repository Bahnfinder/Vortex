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
    let textPositionY: Double // Y-Position des Textes (0.0 = oben, 1.0 = unten)
    
    @State private var rocketSystem: VortexSystem
    @State private var textSystem: VortexSystem
    @State private var hasTriggered = false
    @State private var flashOpacity = 0.0 // Blitz-Effekt
    @State private var textPoints: [CGPoint] = [] // Vorberechnete Punkte
    
    // Rakete fliegt 1.0s
    let flightDuration = 1.0
    
    public init(text: String, fontSize: CGFloat = 40, textPositionY: Double = 0.25) {
        self.text = text
        self.fontSize = fontSize
        self.textPositionY = textPositionY
        
        // 1. Rakete (fliegt hoch)
        let rocket = VortexSystem(
            tags: ["circle"],
            position: [0.5, 1.0], 
            shape: .box(width: 1.0, height: 0),
            birthRate: 0,
            emissionLimit: nil,
            burstCount: 15, // Mehr Action
            lifespan: flightDuration,
            speed: 1.6,
            speedVariation: 0.1, // Minimale Variation für Realismus
            angle: .zero,
            angleRange: .degrees(30), // Breiterer Fächer -> "von überall"
            dampingFactor: 2,
            colors: .single(.white),
            size: 0.15,
            stretchFactor: 4
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
        let textSys = VortexSystem(
            tags: ["circle"],
            birthRate: 0,
            lifespan: 8.0, // 3 Sekunden voll sichtbar + 5 Sekunden Zerfallen und Runterfallen
            speed: 0.001, // Praktisch keine Bewegung, damit Text scharf bleibt
            speedVariation: 0,
            acceleration: [0, 0.002], // Minimale Schwerkraft (fast 0)
            dampingFactor: 0.5, // Wenig Damping nötig bei kaum Speed
            colors: .randomRamp(
                // 3 Sekunden volle Farbe, dann 5 Sekunden langsames Zerfallen
                [.white, .pink, .pink, .pink, .pink, .pink.opacity(0.8), .pink.opacity(0.6), .pink.opacity(0.4), .pink.opacity(0.2), .clear],
                [.white, .blue, .blue, .blue, .blue, .blue.opacity(0.8), .blue.opacity(0.6), .blue.opacity(0.4), .blue.opacity(0.2), .clear],
                [.white, .green, .green, .green, .green, .green.opacity(0.8), .green.opacity(0.6), .green.opacity(0.4), .green.opacity(0.2), .clear],
                [.white, .orange, .orange, .orange, .orange, .orange.opacity(0.8), .orange.opacity(0.6), .orange.opacity(0.4), .orange.opacity(0.2), .clear],
                [.white, .cyan, .cyan, .cyan, .cyan, .cyan.opacity(0.8), .cyan.opacity(0.6), .cyan.opacity(0.4), .cyan.opacity(0.2), .clear],
                [.white, .yellow, .yellow, .yellow, .yellow, .yellow.opacity(0.8), .yellow.opacity(0.6), .yellow.opacity(0.4), .yellow.opacity(0.2), .clear]
            ),
            size: 0.25,
            sizeMultiplierAtDeath: 0.7, // Partikel bleiben groß! (War 0)
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
            
            // Blitz beim Knall
            Color.white
                .opacity(flashOpacity)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true
            
            // Punkte vorberechnen
            prepareTextPoints()
            
            rocketSystem.burst()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration) {
                explodeText()
                // Blitz auslösen
                withAnimation(.easeOut(duration: 0.1)) {
                    flashOpacity = 0.3
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                    flashOpacity = 0
                }
            }
        }
    }
    
    private func prepareTextPoints() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Font Size 2.0x für gute Auflösung
            let points = TextRasterizer.rasterize(text: self.text, fontSize: self.fontSize * 2.0, positionY: self.textPositionY)
            
            DispatchQueue.main.async {
                self.textPoints = points
            }
        }
    }
    
    private func explodeText() {
        // Sofort spawnen, da Punkte schon da sein sollten (nach 1s)
        // Falls Berechnung länger als 1s dauert (unwahrscheinlich), nehmen wir was da ist (leer) oder warten?
        // Bei leer passiert nichts.
        if !textPoints.isEmpty {
            self.textSystem.spawnAt(points: textPoints)
        } else {
            // Fallback: Wenn noch nicht fertig, warten wir kurz (Hack)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !self.textPoints.isEmpty {
                    self.textSystem.spawnAt(points: self.textPoints)
                }
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
            let particle = Particle(
                tag: tags.randomElement() ?? "circle",
                position: SIMD2(Double(point.x), Double(point.y)),
                // Sehr minimale Geschwindigkeit - Text bleibt 3 Sekunden stabil, dann beginnt Zerfallen
                speed: [Double.random(in: -0.001...0.001), Double.random(in: -0.001...0.001)],
                birthTime: currentTime + Double.random(in: 0...0.05),
                lifespan: lifespan + Double.random(in: -0.5...0.5),
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
    static func rasterize(text: String, fontSize: CGFloat, positionY: Double = 0.25) -> [CGPoint] {
        #if canImport(UIKit)
        // Referenz-fontSize für Skalierung (Standard: 40)
        let referenceFontSize: CGFloat = 40.0
        
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
        
        // Ziel-Position (anpassbar)
        let targetCenterX = 0.5
        let targetCenterY = positionY 
        
        // Skalierung: Proportional zur fontSize, damit größere fontSize = größerer Text
        // Bei fontSize 40 sollte Text 85% Breite haben, bei anderen fontSize proportional
        // Maximale Breite: 95% um Überlauf zu vermeiden
        let fontSizeRatio = Double(fontSize) / Double(referenceFontSize)
        let baseWidthAtReference = 0.85 // Bei fontSize 40 ist Text 85% der Breite
        let targetWidth = min(baseWidthAtReference * fontSizeRatio, 0.95) // Max 95% Breite
        let scale = targetWidth / Double(width)
        
        // Adaptive Sampling
        let textPixels = Double(width * height) * 0.25
        let targetCount = 3000.0
        let sampleStep = max(1, Int(sqrt(textPixels / targetCount)))
        
        let buffer = UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: height * bytesPerRow), count: height * bytesPerRow)
        
        // Sampling mit leichter Randomisierung, um Streifen zu vermeiden
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                // Leichte Randomisierung der Sampling-Position (±25% des sampleStep)
                let jitterRange = Double(sampleStep) * 0.25
                let jitteredX = x + Int.random(in: -Int(jitterRange)...Int(jitterRange))
                let jitteredY = y + Int.random(in: -Int(jitterRange)...Int(jitterRange))
                
                // Sicherstellen, dass wir innerhalb der Grenzen bleiben
                let clampedX = max(0, min(jitteredX, width - 1))
                let clampedY = max(0, min(jitteredY, height - 1))
                
                let offset = clampedY * bytesPerRow + clampedX * bytesPerPixel
                
                // Wir prüfen Alpha (letztes Byte bei RGBA) oder Rot (erstes Byte, da Text weiß ist)
                // Bei Weiß (255, 255, 255, 255) ist alles > 0.
                if offset + 3 < buffer.count {
                    let alpha = buffer[offset + 3]
                    
                    if alpha > 50 {
                        let relX = (Double(x) - Double(width) / 2.0)
                        let relY = (Double(y) - Double(height) / 2.0)
                        
                        // Kleine zufällige Variation hinzufügen, um Streifen zu vermeiden
                        // Die Variation ist proportional zur Skalierung, damit sie bei allen Größen gleich aussieht
                        let jitterAmount = scale * 0.3 // 30% der Partikelgröße als Variation
                        let jitterX = Double.random(in: -jitterAmount...jitterAmount)
                        let jitterY = Double.random(in: -jitterAmount...jitterAmount)
                        
                        // Y-Flip für korrekte Ausrichtung
                        let finalX = targetCenterX + (relX * scale) + jitterX
                        let finalY = targetCenterY - (relY * scale) + jitterY
                        
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
