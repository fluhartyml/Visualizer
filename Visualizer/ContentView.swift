//
//  ContentView.swift
//  Visualizer
//
//  Created by Michael Fluharty on 11/25/25.
//

import SwiftUI

struct ContentView: View {
    @State private var audioAnalyzer = AudioAnalyzer()
    @State private var selectedVisualizer: VisualizerType = .spectrum
    @State private var showControls = true

    var body: some View {
        ZStack {
            // Visualizer fills the entire view
            VisualizerContainer(
                type: selectedVisualizer,
                frequencyData: audioAnalyzer.frequencyData,
                amplitude: audioAnalyzer.amplitude
            )
            .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top bar with visualizer picker
                if showControls {
                    VStack(spacing: 12) {
                        // Title
                        Text(audioAnalyzer.currentTrackName.isEmpty ? "Visualizer" : audioAnalyzer.currentTrackName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        // Visualizer type picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VisualizerType.allCases) { type in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedVisualizer = type
                                        }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: type.icon)
                                                .font(.title2)
                                            Text(type.rawValue)
                                                .font(.caption)
                                        }
                                        .frame(width: 70, height: 60)
                                        .background(selectedVisualizer == type ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                    .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom controls
                if showControls {
                    HStack(spacing: 20) {
                        // Demo mode toggle
                        Button {
                            if audioAnalyzer.isPlaying {
                                audioAnalyzer.stopDemoMode()
                            } else {
                                audioAnalyzer.startDemoMode()
                            }
                        } label: {
                            Label(
                                audioAnalyzer.isPlaying ? "Stop Demo" : "Start Demo",
                                systemImage: audioAnalyzer.isPlaying ? "stop.fill" : "play.fill"
                            )
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(audioAnalyzer.isPlaying ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                            .foregroundStyle(.white)
                            .cornerRadius(25)
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial.opacity(0.8))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
