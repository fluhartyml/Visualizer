//
//  AudioAnalyzer.swift
//  Visualizer
//
//  Created by Michael Fluharty on 11/25/25.
//

import AVFoundation
import Accelerate
import Observation

/// Separate FFT processor that's not actor-isolated
final class FFTProcessor: Sendable {
    private let fftSize: Int
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length

    init(fftSize: Int = 2048) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    func performFFT(_ data: UnsafeMutablePointer<Float>, frameCount: Int) -> [Float] {
        let halfSize = fftSize / 2
        var realPart = [Float](repeating: 0, count: halfSize)
        var imagPart = [Float](repeating: 0, count: halfSize)

        // Apply Hanning window
        var windowedData = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        let copyCount = min(frameCount, fftSize)
        for i in 0..<copyCount {
            windowedData[i] = data[i] * window[i]
        }

        // Pack data for FFT
        windowedData.withUnsafeMutableBufferPointer { windowedPtr in
            realPart.withUnsafeMutableBufferPointer { realPtr in
                imagPart.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realPtr.baseAddress!,
                        imagp: imagPtr.baseAddress!
                    )

                    // Convert to split complex format
                    windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfSize))
                    }

                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                    // Calculate magnitudes
                    var magnitudes = [Float](repeating: 0, count: halfSize)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

                    // Convert to dB and normalize
                    var normalizedMagnitudes = [Float](repeating: 0, count: halfSize)
                    var one: Float = 1
                    vDSP_vdbcon(&magnitudes, 1, &one, &normalizedMagnitudes, 1, vDSP_Length(halfSize), 0)

                    // Group into 64 bands and normalize
                    let bandCount = 64
                    let bandsPerGroup = halfSize / bandCount
                    var bands = [Float](repeating: 0, count: bandCount)

                    for i in 0..<bandCount {
                        let startIdx = i * bandsPerGroup
                        let endIdx = min(startIdx + bandsPerGroup, halfSize)
                        var sum: Float = 0
                        for j in startIdx..<endIdx {
                            sum += normalizedMagnitudes[j]
                        }
                        // Normalize: typical dB range is -160 to 0, map to 0-1
                        let avg = sum / Float(endIdx - startIdx)
                        bands[i] = max(0, min(1, (avg + 80) / 80))
                    }

                    // Store result (will be copied out)
                    for i in 0..<bandCount {
                        realPtr[i] = bands[i]
                    }
                }
            }
        }

        return Array(realPart.prefix(64))
    }
}

/// Real-time audio analyzer using AVAudioEngine and FFT
@Observable
@MainActor
final class AudioAnalyzer {
    // MARK: - Published Data

    /// Frequency magnitudes (normalized 0-1), typically 32-64 bands
    private(set) var frequencyData: [Float] = Array(repeating: 0, count: 64)

    /// Current amplitude/volume level (normalized 0-1)
    private(set) var amplitude: Float = 0

    /// Whether audio is currently playing
    private(set) var isPlaying: Bool = false

    /// Current audio file name
    private(set) var currentTrackName: String = ""

    // MARK: - Private Properties

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private let fftProcessor = FFTProcessor()
    private let fftSize: Int = 2048

    // MARK: - Initialization

    init() {
        setupAudioEngine()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        engine.attach(playerNode)

        let mainMixer = engine.mainMixerNode
        let format = mainMixer.outputFormat(forBus: 0)

        engine.connect(playerNode, to: mainMixer, format: format)

        // Install tap on main mixer to analyze audio
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(fftSize)
        let processor = fftProcessor

        mainMixer.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)

            // Calculate amplitude (RMS)
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))
            let normalizedAmplitude = min(rms * 5, 1.0)

            // Perform FFT
            let frequencyBands = processor.performFFT(channelData, frameCount: frameLength)

            // Update on main thread
            Task { @MainActor [weak self] in
                self?.amplitude = normalizedAmplitude
                self?.frequencyData = frequencyBands
            }
        }
    }

    // MARK: - Playback Control

    func loadAudioFile(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        currentTrackName = url.deletingPathExtension().lastPathComponent
    }

    func play() throws {
        guard let audioFile = audioFile else { return }

        if !engine.isRunning {
            try engine.start()
        }

        playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
            }
        }

        playerNode.play()
        isPlaying = true
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        amplitude = 0
        frequencyData = Array(repeating: 0, count: 64)
    }

    func togglePlayPause() throws {
        if isPlaying {
            pause()
        } else {
            try play()
        }
    }

    // MARK: - Demo Mode (generates fake data for testing UI)

    func startDemoMode() {
        isPlaying = true
        currentTrackName = "Demo Mode"
        Task { [weak self] in
            await self?.runDemoLoop()
        }
    }

    func stopDemoMode() {
        isPlaying = false
        currentTrackName = ""
        amplitude = 0
        frequencyData = Array(repeating: 0, count: 64)
    }

    private func runDemoLoop() async {
        while isPlaying {
            // Generate smooth random frequency data
            var newData = [Float](repeating: 0, count: 64)
            for i in 0..<64 {
                let base = Float.random(in: 0.1...0.9)
                // Weight lower frequencies higher (more bass-heavy visualization)
                let weight = 1.0 - (Float(i) / 64.0) * 0.5
                newData[i] = base * weight
            }

            // Smooth transition from current data
            for i in 0..<64 {
                frequencyData[i] = frequencyData[i] * 0.7 + newData[i] * 0.3
            }

            amplitude = Float.random(in: 0.3...0.8)

            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
