//
//  VisualizerContainer.swift
//  Visualizer
//
//  Created by Michael Fluharty on 11/25/25.
//

import SwiftUI

/// Container view that displays the currently selected visualizer
struct VisualizerContainer: View {
    let type: VisualizerType
    let frequencyData: [Float]
    let amplitude: Float

    var body: some View {
        switch type {
        case .waveform:
            WaveformVisualizer(frequencyData: frequencyData, amplitude: amplitude)
        case .spectrum:
            SpectrumVisualizer(frequencyData: frequencyData, amplitude: amplitude)
        case .circular:
            CircularVisualizer(frequencyData: frequencyData, amplitude: amplitude)
        case .particles:
            ParticleVisualizer(frequencyData: frequencyData, amplitude: amplitude)
        case .abstract:
            AbstractVisualizer(frequencyData: frequencyData, amplitude: amplitude)
        }
    }
}

/// Picker for selecting visualizer type
struct VisualizerTypePicker: View {
    @Binding var selection: VisualizerType

    var body: some View {
        Picker("Visualizer", selection: $selection) {
            ForEach(VisualizerType.allCases) { type in
                Label(type.rawValue, systemImage: type.icon)
                    .tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    VStack {
        VisualizerContainer(
            type: .spectrum,
            frequencyData: (0..<64).map { _ in Float.random(in: 0...1) },
            amplitude: 0.7
        )
        .frame(height: 300)
        .background(.black)
    }
}
