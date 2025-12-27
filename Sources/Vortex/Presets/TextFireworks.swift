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
#elseif canImport(AppKit)
import AppKit
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
        
        // 1. System für die Rakete (fliegt hoch)
        let rocket = VortexSystem(
            tags: ["circle"],
            position: [0.5, 1.0], // Startet unten mittig
            birthRate: 0,
            emissionLimit: 1,
            lifespan: 1.2,
            speed: 1.2, // Schnell nach oben
            angle: .degrees(180), // Nach oben (0 ist unten in Vortex Koordinaten oft anders, aber wir testen)
            colors: .single(.white),
            size: 0.3,
            stretchFactor: 4,
            haptics: .default // Wir machen Haptik manuell
        )
        // Schweif für die Rakete
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
        
        // 2. System für den Text (explodiert)
        // Startet leer und wird gefüllt, wenn die Rakete explodiert
        let textSys = VortexSystem(
            tags: ["circle"],
            birthRate: 0,
            lifespan: 3.0,
            speed: 0, // Text bleibt stehen
            colors: .randomRamp(
                [.white, .yellow, .orange, .clear],
                [.white, .blue, .purple, .clear],
                [.white, .pink, .red, .clear]
            ),
            size: 0.5, // GRÖSSER! Vorher 0.1 war zu klein (1.6px), jetzt 0.5 (8px bei 16px Base)
            haptics: .burst(type: .heavy, intensity: 1.0)
        )
        _textSystem = State(initialValue: textSys)
    }
    
    public var body: some View {
        ZStack {
            // Rakete rendern
            VortexView(rocketSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 32)
                    .tag("circle")
                    .blur(radius: 2)
            }
            
            // Text-Explosion rendern
            VortexView(textSystem) {
                Circle()
                    .fill(.white)
                    .frame(width: 16)
                    .tag("circle")
                    .blur(radius: 1)
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            guard !hasTriggered else { return }
            hasTriggered = true
            
            startSequence()
        }
    }
    
    private func startSequence() {
        // 1. Rakete starten
        rocketSystem.burst()
        
        // 2. Warten bis Rakete oben ist, dann Text explodieren lassen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            explodeText()
        }
    }
    
    private func explodeText() {
        // Haptik auslösen
        textSystem.haptics = .burst(type: .heavy, intensity: 1.0)
        
        // Text-Punkte berechnen
        // Wir nutzen eine größere Schriftgröße für mehr Details und skalieren dann runter
        let points = TextRasterizer.rasterize(text: text, fontSize: fontSize * 2, sampleRate: 5)
        
        print("Vortex: Exploding text '\(text)' with \(points.count) particles")
        
        // Partikel manuell hinzufügen
        textSystem.spawnAt(points: points)
    }
}

// MARK: - Helper

extension VortexSystem {
    /// Spawnt Partikel an spezifischen Positionen.
    func spawnAt(points: [CGPoint]) {
        // Sicherstellen, dass das System aktiv ist
        self.isActive = true
        self.isEmitting = true // Muss true sein, damit update() funktioniert
        
        // Haptik manuell triggern
        if haptics.trigger == .onBurst || haptics.trigger == .onBirth {
            HapticsHelper.trigger(&haptics, at: Date().timeIntervalSince1970)
        }
        
        let currentTime = Date().timeIntervalSince1970
        
        for point in points {
            let particle = Particle(
                tag: tags.randomElement() ?? "circle",
                position: SIMD2(Double(point.x), Double(point.y)),
                speed: [Double.random(in: -0.02...0.02), Double.random(in: -0.02...0.02)],
                birthTime: currentTime,
                lifespan: lifespan + Double.random(in: -0.5...0.5),
                initialSize: size * Double.random(in: 0.8...1.2), // Variation in Größe
                angularSpeed: [0,0,0],
                colors: getNewParticleColorRamp()
            )
            particles.append(particle)
        }
        
        // Force update damit die neuen Partikel sofort berücksichtigt werden könnten
        // (VortexView macht das im nächsten Frame sowieso)
    }
}

struct TextRasterizer {
    static func rasterize(text: String, fontSize: CGFloat, sampleRate: Int = 4) -> [CGPoint] {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black) // Fetterer Font für mehr Partikel
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            attributedString.draw(at: .zero)
        }
        
        guard let cgImage = image.cgImage else { return [] }
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return [] }
        
        var points: [CGPoint] = []
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        
        // Zentrierung
        let targetCenterX = 0.5
        let targetCenterY = 0.3
        
        // Skalierung anpassen damit der Text gut auf den Screen passt (Vortex Koordinaten 0..1)
        // Wir wollen, dass der Text ca. 80% der Breite einnimmt
        // width ist Pixelbreite des gerenderten Textes.
        // Wir mappen width -> 0.8
        let targetWidth = 0.8
        let scale = targetWidth / Double(width)
        
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let offset = y * bytesPerRow + x * 4
                let alpha = ptr[offset + 3] // Alpha channel
                
                if alpha > 30 { // Niedrigerer Threshold
                    // Konvertiere zu Vortex Koordinaten
                    // Zentriere den Text um (0,0) im Pixel-Space
                    let relX = (Double(x) - Double(width) / 2.0)
                    let relY = (Double(y) - Double(height) / 2.0)
                    
                    // Skaliere und verschiebe
                    let finalX = targetCenterX + (relX * scale)
                    let finalY = targetCenterY + (relY * scale)
                    
                    points.append(CGPoint(x: finalX, y: finalY))
                }
            }
        }
        return points
        
        #else
        return []
        #endif
    }
}
