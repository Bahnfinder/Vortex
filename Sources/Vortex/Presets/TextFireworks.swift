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
        // Wir berechnen Punkte basierend auf einer festen Ziel-Breite (z.B. 600px für gute Auflösung)
        // Sample Rate wird dynamisch angepasst
        let points = TextRasterizer.rasterize(text: text, fontSize: fontSize * 2)
        
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
        self.isEmitting = true
        
        let currentTime = Date().timeIntervalSince1970
        
        // Begrenze Anzahl der Partikel um Hängen zu vermeiden (Max 3000)
        let maxParticles = 3000
        let stride = max(1, points.count / maxParticles)
        
        for (index, point) in points.enumerated() where index % stride == 0 {
            let particle = Particle(
                tag: tags.randomElement() ?? "circle",
                position: SIMD2(Double(point.x), Double(point.y)),
                speed: [Double.random(in: -0.01...0.01), Double.random(in: -0.01...0.01)],
                birthTime: currentTime,
                lifespan: lifespan + Double.random(in: -0.5...0.5),
                initialSize: size * Double.random(in: 0.5...1.5),
                angularSpeed: [0,0,0],
                colors: getNewParticleColorRamp()
            )
            particles.append(particle)
        }
        
        if haptics.trigger == .onBurst || haptics.trigger == .onBirth {
            HapticsHelper.trigger(&haptics, at: currentTime)
        }
    }
}

struct TextRasterizer {
    static func rasterize(text: String, fontSize: CGFloat) -> [CGPoint] {
        #if canImport(UIKit)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black] // Schwarz auf Transparent
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        // pngData() garantiert ein definiertes Format (RGBA), aber ist teuer.
        // Besser: Wir zeichnen in einen expliziten Bitmap Context.
        
        let width = Int(size.width)
        let height = Int(size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // Raw Pixel Buffer
        var rawData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue // RGBA
        ) else { return [] }
        
        // Text in Context zeichnen
        UIGraphicsPushContext(context)
        attributedString.draw(at: .zero)
        UIGraphicsPopContext()
        
        var points: [CGPoint] = []
        
        // Zentrierung und Skalierung
        let targetCenterX = 0.5
        let targetCenterY = 0.3
        let targetWidth = 0.85
        let scale = targetWidth / Double(width)
        
        // Sampling
        // Ziel: ca. 2000-3000 Punkte insgesamt für gute Performance
        // Wir schätzen die bedeckte Fläche (ca. 30% bei Text)
        let estimatedPixels = Double(width * height) * 0.3
        let targetPoints = 2500.0
        let sampleStep = max(1, Int(sqrt(estimatedPixels / targetPoints)))
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let alpha = rawData[offset + 3] // A ist letztes Byte bei RGBA
                
                if alpha > 20 { // Wenn Pixel sichtbar
                    let relX = (Double(x) - Double(width) / 2.0)
                    let relY = (Double(y) - Double(height) / 2.0)
                    
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
