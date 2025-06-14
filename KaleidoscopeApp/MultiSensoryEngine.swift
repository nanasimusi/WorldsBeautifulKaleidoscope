import Foundation
import CoreHaptics
import AVFoundation
import simd

class MultiSensoryEngine: ObservableObject {
    static let shared = MultiSensoryEngine()
    
    private var hapticEngine: CHHapticEngine?
    private var audioEngine: AVAudioEngine
    private var spatialAudioMixer: AVAudioEnvironmentNode
    private var musicReactiveProcessor: MusicReactiveProcessor
    private var breathController: BreathController
    
    private var isHapticsEnabled = true
    private var is3DAudioEnabled = true
    private var isMusicReactiveEnabled = true
    private var isBreathControlEnabled = false
    
    @Published var currentHapticIntensity: Float = 0.5
    @Published var spatialAudioRadius: Float = 1.0
    @Published var breathingRate: Float = 0.0
    
    private init() {
        audioEngine = AVAudioEngine()
        spatialAudioMixer = AVAudioEnvironmentNode()
        musicReactiveProcessor = MusicReactiveProcessor()
        breathController = BreathController()
        
        setupHaptics()
        setup3DAudio()
        setupMusicReactivity()
        setupBreathControl()
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("Haptics not supported on this device")
            isHapticsEnabled = false
            return
        }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            hapticEngine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
            
            hapticEngine?.resetHandler = {
                print("Haptic engine reset")
                do {
                    try self.hapticEngine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Haptic engine creation failed: \(error)")
            isHapticsEnabled = false
        }
    }
    
    private func setup3DAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowAirPlay])
            try audioSession.setActive(true)
            
            audioEngine.attach(spatialAudioMixer)
            audioEngine.connect(spatialAudioMixer, to: audioEngine.mainMixerNode, format: nil)
            
            spatialAudioMixer.renderingAlgorithm = .HRTFHQ
            spatialAudioMixer.reverbParameters.enable = true
            spatialAudioMixer.reverbParameters.level = 15
            
            try audioEngine.start()
            is3DAudioEnabled = true
        } catch {
            print("3D Audio setup failed: \(error)")
            is3DAudioEnabled = false
        }
    }
    
    private func setupMusicReactivity() {
        musicReactiveProcessor.onBeatDetected = { [weak self] intensity in
            self?.triggerBeatHaptic(intensity: intensity)
        }
        
        musicReactiveProcessor.onFrequencyAnalysis = { [weak self] analysis in
            self?.updateSpatialAudioFromFrequency(analysis: analysis)
        }
    }
    
    private func setupBreathControl() {
        breathController.onBreathDetected = { [weak self] phase, intensity in
            self?.updateBreathingVisualization(phase: phase, intensity: intensity)
        }
    }
    
    func synchronizeWithKaleidoscope(time: Float, patterns: [KaleidoscopePattern], particleCount: Int) {
        updateHapticFeedback(time: time, patterns: patterns, particleCount: particleCount)
        update3DAudio(time: time, patterns: patterns)
        processBreathingInput(time: time)
    }
    
    private func updateHapticFeedback(time: Float, patterns: [KaleidoscopePattern], particleCount: Int) {
        guard isHapticsEnabled, hapticEngine != nil else { return }
        
        let baseIntensity = sin(time * 2.0) * 0.3 + 0.7
        let patternComplexity = Float(patterns.count) / 10.0
        let particleDensity = Float(particleCount) / 10000.0
        
        let finalIntensity = (baseIntensity + patternComplexity + particleDensity) / 3.0
        let sharpness = cos(time * 1.5) * 0.5 + 0.5
        
        createContinuousHaptic(intensity: finalIntensity, sharpness: sharpness, duration: 0.1)
        
        for (index, pattern) in patterns.enumerated() {
            if pattern.shouldTriggerHaptic(time: time) {
                createTransientHaptic(intensity: pattern.intensity, sharpness: pattern.sharpness, delay: Double(index) * 0.05)
            }
        }
    }
    
    private func createContinuousHaptic(intensity: Float, sharpness: Float, duration: TimeInterval) {
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: 0,
            duration: duration
        )
        
        playHapticPattern([event])
    }
    
    private func createTransientHaptic(intensity: Float, sharpness: Float, delay: TimeInterval) {
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: delay
        )
        
        playHapticPattern([event])
    }
    
    private func playHapticPattern(_ events: [CHHapticEvent]) {
        guard let engine = hapticEngine else { return }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Haptic playback failed: \(error)")
        }
    }
    
    private func update3DAudio(time: Float, patterns: [KaleidoscopePattern]) {
        guard is3DAudioEnabled else { return }
        
        for (index, pattern) in patterns.enumerated() {
            let angle = Float(index) * 2.0 * Float.pi / Float(patterns.count) + time * 0.1
            let radius = spatialAudioRadius * (0.5 + pattern.intensity * 0.5)
            
            let position = simd_float3(
                cos(angle) * radius,
                sin(angle) * radius * 0.5,
                sin(time + Float(index)) * 0.3
            )
            
            updateAudioSourcePosition(sourceIndex: index, position: position)
        }
        
        let listenerPosition = simd_float3(0, 0, 0)
        let listenerOrientation = simd_float3(0, 0, -1)
        spatialAudioMixer.listenerPosition = AVAudio3DPoint(x: listenerPosition.x, y: listenerPosition.y, z: listenerPosition.z)
        spatialAudioMixer.listenerVectorOrientation = AVAudio3DVectorOrientation(
            forward: AVAudio3DVector(x: listenerOrientation.x, y: listenerOrientation.y, z: listenerOrientation.z),
            up: AVAudio3DVector(x: 0, y: 1, z: 0)
        )
    }
    
    private func updateAudioSourcePosition(sourceIndex: Int, position: simd_float3) {
        
    }
    
    private func triggerBeatHaptic(intensity: Float) {
        guard isHapticsEnabled else { return }
        createTransientHaptic(intensity: intensity, sharpness: 0.8, delay: 0)
    }
    
    private func updateSpatialAudioFromFrequency(analysis: FrequencyAnalysis) {
        guard is3DAudioEnabled else { return }
        
        let bassIntensity = analysis.bassLevel
        let midIntensity = analysis.midLevel
        let trebleIntensity = analysis.trebleLevel
        
        spatialAudioRadius = 0.5 + bassIntensity * 1.5
        
        spatialAudioMixer.reverbParameters.level = midIntensity * 30
        spatialAudioMixer.distanceAttenuationParameters.rolloffFactor = 1.0 + trebleIntensity
    }
    
    private func processBreathingInput(time: Float) {
        guard isBreathControlEnabled else { return }
        
        breathController.processInput(time: time)
        breathingRate = breathController.currentRate
    }
    
    private func updateBreathingVisualization(phase: BreathPhase, intensity: Float) {
        DispatchQueue.main.async {
            self.breathingRate = intensity
        }
        
        let hapticIntensity = intensity * 0.3
        let hapticSharpness: Float = phase == .inhale ? 0.3 : 0.7
        
        createContinuousHaptic(intensity: hapticIntensity, sharpness: hapticSharpness, duration: 0.5)
    }
    
    func enableHaptics(_ enabled: Bool) {
        isHapticsEnabled = enabled
        if !enabled {
            hapticEngine?.stop()
        } else {
            do {
                try hapticEngine?.start()
            } catch {
                print("Failed to start haptic engine: \(error)")
            }
        }
    }
    
    func enable3DAudio(_ enabled: Bool) {
        is3DAudioEnabled = enabled
        if !enabled {
            audioEngine.stop()
        } else {
            do {
                try audioEngine.start()
            } catch {
                print("Failed to start audio engine: \(error)")
            }
        }
    }
    
    func enableMusicReactivity(_ enabled: Bool) {
        isMusicReactiveEnabled = enabled
        if enabled {
            musicReactiveProcessor.startListening()
        } else {
            musicReactiveProcessor.stopListening()
        }
    }
    
    func enableBreathControl(_ enabled: Bool) {
        isBreathControlEnabled = enabled
        if enabled {
            breathController.startMonitoring()
        } else {
            breathController.stopMonitoring()
        }
    }
}

class MusicReactiveProcessor {
    var onBeatDetected: ((Float) -> Void)?
    var onFrequencyAnalysis: ((FrequencyAnalysis) -> Void)?
    
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    
    init() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
    }
    
    func startListening() {
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine for music reactivity: \(error)")
        }
    }
    
    func stopListening() {
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        
        let analysis = analyzeFrequencies(samples: samples)
        onFrequencyAnalysis?(analysis)
        
        if detectBeat(samples: samples) {
            let intensity = calculateBeatIntensity(samples: samples)
            onBeatDetected?(intensity)
        }
    }
    
    private func analyzeFrequencies(samples: [Float]) -> FrequencyAnalysis {
        let bassRange = samples[0..<min(samples.count/4, samples.count)]
        let midRange = samples[samples.count/4..<min(3*samples.count/4, samples.count)]
        let trebleRange = samples[3*samples.count/4..<samples.count]
        
        let bassLevel = bassRange.map { abs($0) }.reduce(0, +) / Float(bassRange.count)
        let midLevel = midRange.map { abs($0) }.reduce(0, +) / Float(midRange.count)
        let trebleLevel = trebleRange.map { abs($0) }.reduce(0, +) / Float(trebleRange.count)
        
        return FrequencyAnalysis(bassLevel: bassLevel, midLevel: midLevel, trebleLevel: trebleLevel)
    }
    
    private func detectBeat(samples: [Float]) -> Bool {
        let energy = samples.map { $0 * $0 }.reduce(0, +)
        return energy > 0.01
    }
    
    private func calculateBeatIntensity(samples: [Float]) -> Float {
        let maxAmplitude = samples.map { abs($0) }.max() ?? 0
        return min(1.0, maxAmplitude * 10)
    }
}

class BreathController {
    var onBreathDetected: ((BreathPhase, Float) -> Void)?
    
    private var isMonitoring = false
    var currentRate: Float = 0.0
    private var breathingTimer: Timer?
    
    func startMonitoring() {
        isMonitoring = true
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.simulateBreathDetection()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        breathingTimer?.invalidate()
        breathingTimer = nil
    }
    
    func processInput(time: Float) {
        guard isMonitoring else { return }
        
        let breathPhase = sin(time * 0.3) > 0 ? BreathPhase.inhale : BreathPhase.exhale
        let intensity = abs(sin(time * 0.3))
        currentRate = intensity
        
        onBreathDetected?(breathPhase, intensity)
    }
    
    private func simulateBreathDetection() {
        let time = Float(Date().timeIntervalSince1970)
        processInput(time: time)
    }
}

struct KaleidoscopePattern {
    let intensity: Float
    let sharpness: Float
    let frequency: Float
    let phase: Float
    
    func shouldTriggerHaptic(time: Float) -> Bool {
        return fmod(time * frequency + phase, 1.0) < 0.1
    }
}

struct FrequencyAnalysis {
    let bassLevel: Float
    let midLevel: Float
    let trebleLevel: Float
}

enum BreathPhase {
    case inhale, exhale
}