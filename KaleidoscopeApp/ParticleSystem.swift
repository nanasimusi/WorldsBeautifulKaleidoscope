import Metal
import MetalPerformanceShaders
import simd

class ParticleSystem {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var particleUpdatePipeline: MTLComputePipelineState!
    private var particleRenderPipeline: MTLRenderPipelineState!
    
    private var currentParticleBuffer: MTLBuffer!
    private var velocityBuffer: MTLBuffer!
    private var forceBuffer: MTLBuffer!
    private var lifetimeBuffer: MTLBuffer!
    
    private let maxParticles: Int
    private var activeParticles: Int = 0
    
    private var emissionRate: Float = 100.0
    private var lastEmissionTime: CFTimeInterval = 0
    private var particlePool: [Int] = []
    
    struct ParticleUniforms {
        var deltaTime: Float
        var time: Float
        var emitterPosition: simd_float2
        var gravity: simd_float2
        var windForce: simd_float2
        var turbulence: Float
        var attractorStrength: Float
        var dampening: Float
        var colorShift: Float
        var symmetryCount: Int32
        var breathingPhase: Float
        var goldenRatio: Float
    }
    
    struct Particle {
        var position: simd_float4
        var velocity: simd_float4
        var color: simd_float4
        var size: Float
        var life: Float
        var maxLife: Float
        var mass: Float
    }
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue, maxParticles: Int = 10000) {
        self.device = device
        self.commandQueue = commandQueue
        self.maxParticles = maxParticles
        
        setupBuffers()
        setupPipelines()
        initializeParticlePool()
    }
    
    private func setupBuffers() {
        let particleSize = MemoryLayout<Particle>.size
        _ = MemoryLayout<ParticleUniforms>.size
        
        currentParticleBuffer = device.makeBuffer(length: maxParticles * particleSize, options: .storageModeShared)
        velocityBuffer = device.makeBuffer(length: maxParticles * MemoryLayout<simd_float4>.size, options: .storageModeShared)
        forceBuffer = device.makeBuffer(length: maxParticles * MemoryLayout<simd_float4>.size, options: .storageModeShared)
        lifetimeBuffer = device.makeBuffer(length: maxParticles * MemoryLayout<Float>.size, options: .storageModeShared)
        
        initializeParticles()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create Metal library")
        }
        
        guard let updateFunction = library.makeFunction(name: "particle_update_compute"),
              let renderVertexFunction = library.makeFunction(name: "particle_vertex"),
              let renderFragmentFunction = library.makeFunction(name: "particle_fragment") else {
            fatalError("Could not create particle functions")
        }
        
        do {
            particleUpdatePipeline = try device.makeComputePipelineState(function: updateFunction)
            
            let renderDescriptor = MTLRenderPipelineDescriptor()
            renderDescriptor.vertexFunction = renderVertexFunction
            renderDescriptor.fragmentFunction = renderFragmentFunction
            renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
            renderDescriptor.colorAttachments[0].isBlendingEnabled = true
            renderDescriptor.colorAttachments[0].rgbBlendOperation = .add
            renderDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            renderDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            
            particleRenderPipeline = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        } catch {
            fatalError("Could not create particle pipelines: \(error)")
        }
    }
    
    private func initializeParticlePool() {
        particlePool = Array(0..<maxParticles)
    }
    
    private func initializeParticles() {
        let particles = currentParticleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
        
        for i in 0..<maxParticles {
            particles[i] = Particle(
                position: simd_float4(0, 0, 0, 1),
                velocity: simd_float4(0, 0, 0, 0),
                color: simd_float4(1, 1, 1, 0),
                size: 0.0,
                life: 0.0,
                maxLife: 1.0,
                mass: 1.0
            )
        }
    }
    
    func update(deltaTime: Float, time: Float, uniforms: ParticleUniforms) {
        emitParticles(deltaTime: deltaTime, time: time)
        updateParticles(deltaTime: deltaTime, time: time, uniforms: uniforms)
    }
    
    private func emitParticles(deltaTime: Float, time: Float) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let timeSinceLastEmission = currentTime - lastEmissionTime
        
        if timeSinceLastEmission > 1.0 / Double(emissionRate) {
            let particlesToEmit = min(Int(Float(timeSinceLastEmission) * emissionRate), particlePool.count)
            
            let particles = currentParticleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
            
            for _ in 0..<particlesToEmit {
                if let index = particlePool.popLast() {
                    emitParticle(at: index, particles: particles, time: time)
                    activeParticles += 1
                }
            }
            
            lastEmissionTime = currentTime
        }
    }
    
    private func emitParticle(at index: Int, particles: UnsafeMutablePointer<Particle>, time: Float) {
        let angle = Float.random(in: 0...2 * Float.pi)
        let radius = Float.random(in: 0.05...0.15)
        let speed = Float.random(in: 0.5...2.0)
        
        let position = simd_float2(cos(angle) * radius, sin(angle) * radius)
        let velocity = simd_float2(cos(angle) * speed, sin(angle) * speed) * 0.1
        
        let hue = fract(time * 0.1 + Float(index) * 0.01)
        let color = hsvToRgb(h: hue, s: 0.8, v: 1.0)
        
        particles[index] = Particle(
            position: simd_float4(position.x, position.y, 0, 1),
            velocity: simd_float4(velocity.x, velocity.y, 0, 0),
            color: simd_float4(color.x, color.y, color.z, 1.0),
            size: Float.random(in: 0.002...0.008),
            life: Float.random(in: 2.0...5.0),
            maxLife: Float.random(in: 2.0...5.0),
            mass: Float.random(in: 0.5...2.0)
        )
    }
    
    private func updateParticles(deltaTime: Float, time: Float, uniforms: ParticleUniforms) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        var mutableUniforms = uniforms
        mutableUniforms.deltaTime = deltaTime
        mutableUniforms.time = time
        
        computeEncoder.setComputePipelineState(particleUpdatePipeline)
        computeEncoder.setBuffer(currentParticleBuffer, offset: 0, index: 0)
        computeEncoder.setBytes(&mutableUniforms, length: MemoryLayout<ParticleUniforms>.size, index: 1)
        
        let threadGroupSize = MTLSize(width: 64, height: 1, depth: 1)
        let threadGroups = MTLSize(width: (maxParticles + 63) / 64, height: 1, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        recycleDeadParticles()
    }
    
    private func recycleDeadParticles() {
        let particles = currentParticleBuffer.contents().bindMemory(to: Particle.self, capacity: maxParticles)
        
        for i in 0..<maxParticles {
            if particles[i].life <= 0 && particles[i].color.w > 0 {
                particles[i].color.w = 0
                particlePool.append(i)
                activeParticles = max(0, activeParticles - 1)
            }
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: ParticleUniforms) {
        var mutableUniforms = uniforms
        
        renderEncoder.setRenderPipelineState(particleRenderPipeline)
        renderEncoder.setVertexBuffer(currentParticleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&mutableUniforms, length: MemoryLayout<ParticleUniforms>.size, index: 1)
        renderEncoder.setFragmentBytes(&mutableUniforms, length: MemoryLayout<ParticleUniforms>.size, index: 0)
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: maxParticles)
    }
    
    func getActiveParticleCount() -> Int {
        return activeParticles
    }
    
    func setEmissionRate(_ rate: Float) {
        emissionRate = rate
    }
    
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