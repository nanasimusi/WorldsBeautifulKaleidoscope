import Metal
import MetalKit
import simd
import CoreHaptics
import CoreMotion

class KaleidoscopeRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipelineState: MTLRenderPipelineState!
    private var computePipelineState: MTLComputePipelineState!
    
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    private var particleBuffer: MTLBuffer!
    
    private var time: Float = 0.0
    private let particleCount = 4437  // Match debug info from crash report
    
    private var hapticEngine: CHHapticEngine?
    
    // Performance tracking
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var averageFrameTime: Float = 0
    
    // Living colors animation state
    private var colorBreathingPhase: Float = 0
    private var colorTemperatureShift: Float = 0
    private var saturationPulse: Float = 0
    
    // Interaction state
    private var motionManager = CMMotionManager()
    private var tapIntensity: Float = 0
    private var swipeEffect: Float = 0
    private var motionEffect: Float = 0
    private var motionIntensity: Float = 0
    private var lastMotionTime: TimeInterval = 0
    
    struct Uniforms {
        var time: Float
        var resolution: simd_float2
        var aspectRatio: Float
        var colorShift: Float
        var complexity: Float
        var symmetry: Int32
        var goldenRatio: Float
        var breathing: Float
        // Living colors parameters
        var colorBreathing: Float
        var colorTemperature: Float
        var saturationPulse: Float
        var organicPhase: Float
        // Interaction parameters
        var tapIntensity: Float
        var swipeEffect: Float
        var motionEffect: Float
        var interactionPhase: Float
    }
    
    struct Particle {
        var position: simd_float2    // 8 bytes (2 * 4)
        var velocity: simd_float2    // 8 bytes (2 * 4)
        var color: simd_float4       // 16 bytes (4 * 4)
        var life: Float              // 4 bytes
        var size: Float              // 4 bytes
        var padding: simd_float2     // 8 bytes - padding for 16-byte alignment
        
        init(position: simd_float2, velocity: simd_float2, color: simd_float4, life: Float, size: Float) {
            self.position = position
            self.velocity = velocity
            self.color = color
            self.life = life
            self.size = size
            self.padding = simd_float2(0, 0)  // Initialize padding
        }
    }
    
    init(metalView: MTKView) {
        guard let device = metalView.device else {
            fatalError("Metal device not available")
        }
        
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        
        super.init()
        
        metalView.delegate = self
        
        // Ensure MTKView is properly configured as a backup
        ensureMTKViewConfiguration(metalView)
        
        // Validate MTKView format configuration
        validateMTKViewConfiguration(metalView)
        
        setupMetal()
        setupBuffers()
        setupHaptics()
        setupInteractions()
    }
    
    private func ensureMTKViewConfiguration(_ metalView: MTKView) {
        print("Ensuring MTKView configuration...")
        
        // Force set the configuration if not already set
        if metalView.colorPixelFormat.rawValue == 0 {
            print("Setting color format to .bgra8Unorm_srgb")
            metalView.colorPixelFormat = .bgra8Unorm_srgb
        }
        
        if metalView.depthStencilPixelFormat.rawValue == 0 {
            print("Setting depth format to .depth32Float")
            metalView.depthStencilPixelFormat = .depth32Float
        }
        
        if metalView.preferredFramesPerSecond == 0 {
            print("Setting preferred frames per second to 120")
            metalView.preferredFramesPerSecond = 120
        }
        
        print("MTKView configuration ensured:")
        print("  - Color format: \(metalView.colorPixelFormat)")
        print("  - Depth format: \(metalView.depthStencilPixelFormat)")
        print("  - FPS: \(metalView.preferredFramesPerSecond)")
    }
    
    private func validateMTKViewConfiguration(_ metalView: MTKView) {
        print("MTKView configuration validation:")
        print("  - Color format: \(metalView.colorPixelFormat) (rawValue: \(metalView.colorPixelFormat.rawValue))")
        print("  - Depth/Stencil format: \(metalView.depthStencilPixelFormat) (rawValue: \(metalView.depthStencilPixelFormat.rawValue))")
        print("  - Sample count: \(metalView.sampleCount)")
        print("  - Device: \(metalView.device?.name ?? "nil")")
        
        // Check for invalid formats (rawValue: 0)
        if metalView.depthStencilPixelFormat.rawValue == 0 {
            print("ERROR: MTKView depth format is invalid (rawValue: 0)")
            print("Attempting to set correct depth format...")
            metalView.depthStencilPixelFormat = .depth32Float
            print("Updated depth format to: \(metalView.depthStencilPixelFormat)")
        }
        
        if metalView.colorPixelFormat.rawValue == 0 {
            print("ERROR: MTKView color format is invalid (rawValue: 0)")
            print("Attempting to set correct color format...")
            metalView.colorPixelFormat = .bgra8Unorm_srgb
            print("Updated color format to: \(metalView.colorPixelFormat)")
        }
        
        // Ensure we have the expected depth format
        guard metalView.depthStencilPixelFormat == .depth32Float else {
            fatalError("MTKView depth format mismatch: expected .depth32Float, got \(metalView.depthStencilPixelFormat) (rawValue: \(metalView.depthStencilPixelFormat.rawValue))")
        }
        
        // Ensure we have the expected color format
        guard metalView.colorPixelFormat == .bgra8Unorm_srgb else {
            fatalError("MTKView color format mismatch: expected .bgra8Unorm_srgb, got \(metalView.colorPixelFormat) (rawValue: \(metalView.colorPixelFormat.rawValue))")
        }
        
        // Verify device supports depth format
        if let device = metalView.device {
            print("Metal device info:")
            print("  - Name: \(device.name)")
            print("  - Supports depth32Float: \(device.supportsFamily(.mac2) || device.supportsFamily(.apple1))")
        }
        
        print("✅ MTKView configuration validated successfully")
    }
    
    private func setupInteractions() {
        setupMotionDetection()
    }
    
    private func setupMotionDetection() {
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
    }
    
    private func startMotionUpdates() {
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
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        let acceleration = data.acceleration
        let magnitude = sqrt(acceleration.x * acceleration.x + 
                           acceleration.y * acceleration.y + 
                           acceleration.z * acceleration.z)
        
        // Update motion intensity for visual effects
        motionIntensity = Float(min(magnitude / 3.0, 1.0))  // Normalize to 0-1
        
        // Detect shake gesture
        let shakeThreshold: Double = 2.5
        if magnitude > shakeThreshold {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastMotionTime > 0.5 {  // Prevent rapid triggers
                lastMotionTime = currentTime
                handleShakeInteraction()
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
        
        // Trigger rotation callback if significant rotation detected
        let rotationThreshold: Double = 1.0
        let rotationMagnitude = simd_length(rotationVector)
        if rotationMagnitude > Float(rotationThreshold) {
            handleRotationInteraction(rotation: rotationVector)
        }
    }
    
    func handleTapInteraction(at location: CGPoint) {
        // Trigger ripple effect from tap location
        tapIntensity = 1.0
        
        // Add organic randomness to pattern
        colorTemperatureShift += Float.random(in: -0.5...0.5)
        saturationPulse += Float.random(in: 0.2...0.8)
        
        print("Tap interaction at \(location)")
    }
    
    func handleSwipeInteraction(direction: SwipeDirection) {
        // Change pattern flow direction based on swipe
        swipeEffect = 1.0
        
        switch direction {
        case .up:
            colorBreathingPhase += 1.0
        case .down:
            colorBreathingPhase -= 1.0
        case .left:
            colorTemperatureShift -= 0.5
        case .right:
            colorTemperatureShift += 0.5
        }
        
        print("Swipe interaction: \(direction)")
    }
    
    private func handleShakeInteraction() {
        // Dramatic pattern transformation on shake
        colorBreathingPhase = Float.random(in: 0...2 * Float.pi)
        colorTemperatureShift = Float.random(in: 0...2 * Float.pi)
        saturationPulse = Float.random(in: 0...2 * Float.pi)
        
        // Intense visual burst
        tapIntensity = 2.0
        swipeEffect = 1.5
        
        print("Shake interaction detected!")
    }
    
    private func handleRotationInteraction(rotation: simd_float3) {
        // Subtle motion-based effects
        let rotationMagnitude = simd_length(rotation)
        motionEffect = min(rotationMagnitude, 1.0)
        
        // Influence color temperature based on rotation
        colorTemperatureShift += rotation.z * 0.1
    }
    
    private func setupMetal() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create Metal library")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        let computeFunction = library.makeFunction(name: "particle_compute")
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Configure color attachment
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        
        // CRITICAL: Set depth format to match MTKView's depthStencilPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        print("Render pipeline configuration:")
        print("  - Color format: \(renderPipelineDescriptor.colorAttachments[0].pixelFormat)")
        print("  - Depth format: \(renderPipelineDescriptor.depthAttachmentPixelFormat)")
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            computePipelineState = try device.makeComputePipelineState(function: computeFunction!)
            
            print("✅ Render pipeline created successfully with matching depth format")
            print("  - Pipeline depth format: \(renderPipelineDescriptor.depthAttachmentPixelFormat)")
            
        } catch {
            fatalError("Could not create pipeline states: \(error)")
        }
    }
    
    private func setupBuffers() {
        let vertices: [Float] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
             1.0,  1.0
        ]
        
        guard let vBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: []) else {
            fatalError("Failed to create vertex buffer")
        }
        vertexBuffer = vBuffer
        
        guard let uBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: .storageModeShared) else {
            fatalError("Failed to create uniform buffer")
        }
        uniformBuffer = uBuffer
        
        let particleSize = MemoryLayout<Particle>.size
        let particleAlignment = MemoryLayout<Particle>.alignment
        let particleStride = MemoryLayout<Particle>.stride
        
        // Ensure buffer size is properly aligned
        let alignedParticleSize = (particleSize + particleAlignment - 1) & ~(particleAlignment - 1)
        let particleBufferSize = particleCount * alignedParticleSize
        
        print("Particle memory layout:")
        print("  - size: \(particleSize) bytes")
        print("  - alignment: \(particleAlignment) bytes") 
        print("  - stride: \(particleStride) bytes")
        print("  - aligned size: \(alignedParticleSize) bytes")
        print("  - particle count: \(particleCount)")
        print("  - total buffer size: \(particleBufferSize) bytes")
        
        // Verify the size calculation matches expected size
        let expectedSize = 200000  // From debug info
        if particleBufferSize != expectedSize {
            print("WARNING: Buffer size mismatch! Expected: \(expectedSize), Calculated: \(particleBufferSize)")
        }
        
        guard let pBuffer = device.makeBuffer(length: max(particleBufferSize, expectedSize), options: .storageModeShared) else {
            fatalError("Failed to create particle buffer of size \(max(particleBufferSize, expectedSize))")
        }
        particleBuffer = pBuffer
        
        // Zero out the buffer to ensure clean initialization
        memset(pBuffer.contents(), 0, pBuffer.length)
        
        validateParticleLayout()
        initializeParticles()
    }
    
    private func validateParticleLayout() {
        print("Particle struct validation:")
        print("  - position offset: \(MemoryLayout<Particle>.offset(of: \.position)!)")
        print("  - velocity offset: \(MemoryLayout<Particle>.offset(of: \.velocity)!)")
        print("  - color offset: \(MemoryLayout<Particle>.offset(of: \.color)!)")
        print("  - life offset: \(MemoryLayout<Particle>.offset(of: \.life)!)")
        print("  - size offset: \(MemoryLayout<Particle>.offset(of: \.size)!)")
        print("  - padding offset: \(MemoryLayout<Particle>.offset(of: \.padding)!)")
        print("  - total size: \(MemoryLayout<Particle>.size)")
        print("  - stride: \(MemoryLayout<Particle>.stride)")
        print("  - alignment: \(MemoryLayout<Particle>.alignment)")
        
        // Verify 16-byte alignment for Metal compatibility
        let alignment = MemoryLayout<Particle>.alignment
        if alignment < 16 {
            print("WARNING: Particle alignment (\(alignment)) may not be optimal for Metal")
        }
    }
    
    private func initializeParticles() {
        guard let bufferContents = particleBuffer?.contents() else {
            fatalError("Particle buffer contents is nil")
        }
        
        let particleStride = MemoryLayout<Particle>.stride
        let particleSize = MemoryLayout<Particle>.size
        let bufferSize = particleBuffer.length
        let maxParticles = bufferSize / particleStride
        
        print("Buffer initialization:")
        print("  - buffer size: \(bufferSize) bytes")
        print("  - particle stride: \(particleStride) bytes")
        print("  - particle size: \(particleSize) bytes") 
        print("  - max particles that fit: \(maxParticles)")
        print("  - requested particles: \(particleCount)")
        
        // Ensure we don't exceed buffer capacity
        let safeParticleCount = min(particleCount, maxParticles)
        if safeParticleCount < particleCount {
            print("WARNING: Reducing particle count from \(particleCount) to \(safeParticleCount) to fit in buffer")
        }
        
        // Use stride-based access for proper alignment
        for i in 0..<safeParticleCount {
            let offset = i * particleStride
            guard offset + particleSize <= bufferSize else {
                print("ERROR: Particle \(i) would exceed buffer bounds (offset: \(offset), size: \(particleSize), buffer: \(bufferSize))")
                break
            }
            
            let angle = Float(i) * Float.pi * 2.0 / Float(safeParticleCount)
            let radius = Float.random(in: 0.1...0.8)
            
            // Create organic particle with breathing life cycle
            let lifePhase = sin(Float(i) * 0.1 + time * 0.2)
            let organicSize = 0.005 + sin(Float(i) * 0.3) * 0.003
            
            // Color harmonies that evolve over time
            let hueBase = Float(i) / Float(safeParticleCount)
            let hue = fract(hueBase + time * 0.05)  // Slow color evolution
            let rgb = hsvToRgb(h: hue, s: 0.7 + lifePhase * 0.3, v: 0.8 + lifePhase * 0.2)
            
            let particle = Particle(
                position: simd_float2(cos(angle) * radius, sin(angle) * radius),
                velocity: simd_float2(
                    Float.random(in: -0.005...0.005) * (1.0 + lifePhase * 0.5),
                    Float.random(in: -0.005...0.005) * (1.0 + lifePhase * 0.5)
                ),
                color: simd_float4(rgb.x, rgb.y, rgb.z, 0.8 + lifePhase * 0.2),
                life: 0.5 + lifePhase * 0.5,  // Organic life cycle
                size: organicSize
            )
            
            // Use stride-based pointer arithmetic for safe access
            let particlePointer = bufferContents.advanced(by: offset).assumingMemoryBound(to: Particle.self)
            particlePointer.pointee = particle
        }
        
        print("Successfully initialized \(safeParticleCount) particles with stride-based access")
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine creation failed: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        // Performance tracking
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(currentTime - lastFrameTime)
        lastFrameTime = currentTime
        
        // Update frame statistics
        frameCount += 1
        averageFrameTime = (averageFrameTime * 0.9) + (deltaTime * 0.1)
        
        // Early exit for performance
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // Use actual frame time for smooth animation
        time += deltaTime
        
        // Update living colors state
        updateLivingColors(deltaTime: deltaTime)
        
        // Update uniforms with living colors
        updateUniforms(view: view)
        
        // Skip particle updates if performance is poor (adaptive quality)
        if averageFrameTime < 1.0/30.0 {  // Only update particles if we're above 30fps
            updateParticles(commandBuffer: commandBuffer)
        }
        
        // Dynamic clear color based on living colors
        let clearIntensity = 0.05 + colorBreathingPhase * 0.02
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(
            clearIntensity * 0.2, clearIntensity * 0.1, clearIntensity * 0.3, 1.0
        )
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(particleBuffer, offset: 0, index: 1)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Log performance occasionally
        if frameCount % 300 == 0 {  // Every 5 seconds at 60fps
            let fps = 1.0 / averageFrameTime
            print("Performance: \(String(format: "%.1f", fps)) fps, avg frame time: \(String(format: "%.1f", averageFrameTime * 1000))ms")
        }
        
        // Trigger haptic feedback less frequently for performance
        if frameCount % 6 == 0 {  // Every 6 frames (~10fps)
            triggerHapticFeedback()
        }
    }
    
    private func updateLivingColors(deltaTime: Float) {
        // Breathing effect - like a slow, organic pulse
        colorBreathingPhase += deltaTime * 0.5  // 2-second cycle
        let breathingCycle = sin(colorBreathingPhase)
        
        // Color temperature shifts - warm to cool like day/night
        colorTemperatureShift += deltaTime * 0.1  // 20-second cycle
        
        // Saturation pulse - like a heartbeat
        saturationPulse += deltaTime * 1.2  // ~1 second cycle, like resting heart rate
        
        // Decay interaction effects over time
        tapIntensity = max(0, tapIntensity - deltaTime * 2.0)  // Fade over 0.5 seconds
        swipeEffect = max(0, swipeEffect - deltaTime * 1.5)   // Fade over ~0.67 seconds
        
        // Apply motion effects from device movement
        motionEffect = motionIntensity * 0.5  // Scale down motion input
        
        // Keep values in reasonable ranges
        if colorBreathingPhase > 2 * Float.pi {
            colorBreathingPhase -= 2 * Float.pi
        }
        if colorTemperatureShift > 2 * Float.pi {
            colorTemperatureShift -= 2 * Float.pi
        }
        if saturationPulse > 2 * Float.pi {
            saturationPulse -= 2 * Float.pi
        }
    }
    
    private func updateUniforms(view: MTKView) {
        guard let bufferContents = uniformBuffer?.contents() else {
            print("Warning: uniform buffer contents is nil")
            return
        }
        let uniformPointer = bufferContents.bindMemory(to: Uniforms.self, capacity: 1)
        
        let goldenRatio: Float = 1.618033988749
        let breathing = sin(time * 0.5) * 0.5 + 0.5
        
        // Calculate living colors values
        let breathingCycle = sin(colorBreathingPhase) * 0.5 + 0.5
        let temperatureCycle = sin(colorTemperatureShift) * 0.5 + 0.5
        let heartbeatPulse = sin(saturationPulse) * 0.3 + 0.7
        let organicPhase = sin(time * 0.08) * cos(time * 0.13) * 0.2  // Complex organic movement
        
        uniformPointer.pointee = Uniforms(
            time: time,
            resolution: simd_float2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            aspectRatio: Float(view.drawableSize.width / view.drawableSize.height),
            colorShift: sin(time * 0.3) * 0.5 + 0.5,
            complexity: 3.0 + sin(time * 0.1) * 2.0,
            symmetry: Int32(6 + Int(sin(time * 0.05) * 3)),
            goldenRatio: goldenRatio,
            breathing: breathing,
            // Living colors
            colorBreathing: breathingCycle,
            colorTemperature: temperatureCycle,
            saturationPulse: heartbeatPulse,
            organicPhase: organicPhase,
            // Interactions
            tapIntensity: tapIntensity,
            swipeEffect: swipeEffect,
            motionEffect: motionEffect,
            interactionPhase: sin(time * 3.0) * 0.5 + 0.5  // Fast interaction animation
        )
    }
    
    private func updateParticles(commandBuffer: MTLCommandBuffer) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(uniformBuffer, offset: 0, index: 1)
        
        let threadsPerGroup = MTLSize(width: 64, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (particleCount + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
    }
    
    private func triggerHapticFeedback() {
        guard let engine = hapticEngine else { return }
        
        let intensity = sin(time * 2.0) * 0.3 + 0.7
        let sharpness = cos(time * 1.5) * 0.5 + 0.5
        
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))
        
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensityParameter, sharpnessParameter], relativeTime: 0, duration: 0.1)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Haptic playback failed: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func hsvToRgb(h: Float, s: Float, v: Float) -> simd_float3 {
        let c = v * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = v - c
        
        var rgb: simd_float3
        let hueSegment = Int(h * 6) % 6
        
        switch hueSegment {
        case 0: rgb = simd_float3(c, x, 0)
        case 1: rgb = simd_float3(x, c, 0)
        case 2: rgb = simd_float3(0, c, x)
        case 3: rgb = simd_float3(0, x, c)
        case 4: rgb = simd_float3(x, 0, c)
        default: rgb = simd_float3(c, 0, x)
        }
        
        return rgb + simd_float3(m, m, m)
    }
    
    private func fract(_ x: Float) -> Float {
        return x - floor(x)
    }
}