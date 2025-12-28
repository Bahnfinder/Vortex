//
// FireworksView.swift
// Vortex
// https://www.github.com/twostraws/Vortex
// See LICENSE for license information.
//

import SwiftUI
import Vortex

/// A sample view demonstrating the built-in fireworks preset.
struct FireworksView: View {
    @State private var isActive = true
    @State private var isPaused = false
    
    var body: some View {
        VortexViewReader { proxy in
            ZStack {
                VortexView(.fireworks.makeUniqueCopy()) {
                    Circle()
                        .fill(.white)
                        .frame(width: 32)
                        .blur(radius: 5)
                        .blendMode(.plusLighter)
                        .tag("circle")
                }
                
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Button(isActive ? "Stop" : "Start") {
                            isActive.toggle()
                            if isActive {
                                proxy.start()
                            } else {
                                proxy.stop()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(isPaused ? "Resume" : "Pause") {
                            isPaused.toggle()
                            if isPaused {
                                proxy.pause()
                            } else {
                                proxy.resume()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isActive)
                    }
                    .padding()
                }
            }
        }
        .navigationSubtitle("Demonstrates multi-stage effects")
        .ignoresSafeArea(edges: .top)
    }
}

#Preview {
    FireworksView()
}
