import Foundation
import CoreMotion
#if os(iOS)
import UIKit
#endif

class InteractionManager: ObservableObject {
    static let shared = InteractionManager()
    
    #if os(iOS)
    private let motionManager = CMMotionManager()
    #else
    // macOS用ダミー
    private let motionManager: Any? = nil
    #endif
    private var lastMotionTime: TimeInterval = 0
    
    // Motion sensitivity thresholds
    private let shakeThreshold: Double = 2.5
    private let rotationThreshold: Double = 1.0
    
    // Interaction state
    @Published var motionIntensity: Float = 0.0
    @Published var deviceRotation: simd_float3 = simd_float3(0, 0, 0)
    @Published var shakeDetected: Bool = false
    
    // Gesture callbacks
    var onTap: ((CGPoint) -> Void)?
    var onSwipe: ((SwipeDirection) -> Void)?
    var onShake: (() -> Void)?
    var onRotation: ((simd_float3) -> Void)?
    
    private init() {
        #if os(iOS)
        setupMotionDetection()
        #else
        // macOSでは何もしない
        #endif
    }
    
    private func setupMotionDetection() {
        #if os(iOS)
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }
        
        // Configure accelerometer
        motionManager.accelerometerUpdateInterval = 1.0 / 60.0  // 60 Hz
        
        // Configure gyroscope if available
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 60.0
        }
        
        startMotionUpdates()
        #else
        // macOSでは何もしない
        #endif
    }
    
    func startMotionUpdates() {
        #if os(iOS)
        // Start accelerometer updates for shake detection
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, let data = data else { return }
            self.processAccelerometerData(data)
        }
        
        // Start gyroscope updates for rotation detection
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: .main) { [weak self] data, error in
                guard let self = self, let data = data else { return }
                self.processGyroscopeData(data)
            }
        }
        #else
        // macOSでは何もしない
        #endif
    }
    
    func stopMotionUpdates() {
        #if os(iOS)
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        #else
        // macOSでは何もしない
        #endif
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let magnitude = sqrt(acceleration.x * acceleration.x + 
                           acceleration.y * acceleration.y + 
                           acceleration.z * acceleration.z)
        
        // Update motion intensity for visual effects
        DispatchQueue.main.async {
            self.motionIntensity = Float(min(magnitude / 3.0, 1.0))  // Normalize to 0-1
        }
        
        // Detect shake gesture
        if magnitude > shakeThreshold {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastMotionTime > 0.5 {  // Prevent rapid triggers
                lastMotionTime = currentTime
                DispatchQueue.main.async {
                    self.shakeDetected = true
                    self.onShake?()
                    
                    // Reset shake detection after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.shakeDetected = false
                    }
                }
            }
        }
    }
    
    private func processGyroscopeData(_ data: CMGyroData) {
        let rotation = data.rotationRate
        let rotationVector = simd_float3(
            Float(rotation.x),
            Float(rotation.y), 
            Float(rotation.z)
        )
        
        DispatchQueue.main.async {
            self.deviceRotation = rotationVector
            
            // Trigger rotation callback if significant rotation detected
            let rotationMagnitude = simd_length(rotationVector)
            if rotationMagnitude > Float(self.rotationThreshold) {
                self.onRotation?(rotationVector)
            }
        }
    }
    
    // Gesture handling methods
    func handleTap(at location: CGPoint) {
        #if os(iOS)
        onTap?(location)
        #else
        // macOSでは何もしない
        #endif
    }
    
    func handleSwipe(direction: SwipeDirection) {
        #if os(iOS)
        onSwipe?(direction)
        #else
        // macOSでは何もしない
        #endif
    }
}

enum SwipeDirection {
    case up, down, left, right
}