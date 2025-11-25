//
//  VisualizerProtocol.swift
//  Visualizer
//
//  Created by Michael Fluharty on 11/25/25.
//

import SwiftUI

/// Protocol that all visualizers must conform to
protocol VisualizerView: View {
    /// The audio data to visualize (frequency magnitudes, normalized 0-1)
    var frequencyData: [Float] { get }

    /// The amplitude/volume level (normalized 0-1)
    var amplitude: Float { get }
}

/// Available visualizer types
enum VisualizerType: String, CaseIterable, Identifiable {
    case waveform = "Waveform"
    case spectrum = "Spectrum"
    case circular = "Circular"
    case particles = "Particles"
    case abstract = "Abstract"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .waveform: return "waveform"
        case .spectrum: return "chart.bar.fill"
        case .circular: return "circle.hexagongrid.fill"
        case .particles: return "sparkles"
        case .abstract: return "lasso.badge.sparkles"
        }
    }

    var description: String {
        switch self {
        case .waveform: return "Classic audio waveform display"
        case .spectrum: return "Frequency spectrum analyzer bars"
        case .circular: return "Radial frequency visualization"
        case .particles: return "Reactive particle effects"
        case .abstract: return "Morphing geometric shapes"
        }
    }
}
