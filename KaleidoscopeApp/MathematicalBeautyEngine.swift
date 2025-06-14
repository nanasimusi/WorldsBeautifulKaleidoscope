import Foundation
import simd

class MathematicalBeautyEngine {
    static let shared = MathematicalBeautyEngine()
    
    private let goldenRatio: Float = 1.618033988749
    private let phi: Float = 1.618033988749
    private let tau: Float = Float.pi * 2.0
    
    private init() {}
    
    func generateFractalParameters(time: Float, complexity: Float) -> FractalParameters {
        let baseComplexity = 3.0 + sin(time * 0.1) * 2.0
        let adaptiveComplexity = mix(baseComplexity, complexity, 0.7)
        
        return FractalParameters(
            mandelbrotIterations: Int(adaptiveComplexity * 20),
            juliaIterations: Int(adaptiveComplexity * 15),
            juliaC: simd_float2(
                sin(time * 0.2) * 0.8,
                cos(time * 0.25) * 0.8
            ),
            zoom: 1.0 + sin(time * 0.05) * 0.3,
            rotation: time * 0.03
        )
    }
    
    func calculateGoldenSpiralPoints(centerPoint: simd_float2, time: Float, pointCount: Int) -> [simd_float2] {
        var points: [simd_float2] = []
        
        for index in 0..<pointCount {
            let theta = Float(index) / Float(pointCount) * 4.0 * Float.pi
            let radius = pow(goldenRatio, theta / Float.pi) * 0.1
            let angle = theta + time * 0.1
            
            let point = simd_float2(
                cos(angle) * radius + centerPoint.x,
                sin(angle) * radius + centerPoint.y
            )
            points.append(point)
        }
        
        return points
    }
    
    func generateFibonacciSpiral(time: Float) -> FibonacciSpiral {
        let breathingFactor = sin(time * 0.5) * 0.2 + 1.0
        let rotationOffset = time * 0.1
        
        return FibonacciSpiral(
            scale: breathingFactor,
            rotation: rotationOffset,
            density: 8.0 + sin(time * 0.3) * 4.0,
            amplitude: 0.5 + cos(time * 0.2) * 0.3
        )
    }
    
    func calculateKaleidoscopeSymmetry(time: Float, baseSymmetry: Int) -> KaleidoscopeSymmetry {
        let dynamicSymmetry = baseSymmetry + Int(sin(time * 0.05) * 3)
        let symmetryCount = max(3, min(12, dynamicSymmetry))
        
        let angleStep = tau / Float(symmetryCount)
        let breathingPhase = sin(time * 0.4) * 0.1
        
        return KaleidoscopeSymmetry(
            count: symmetryCount,
            angleStep: angleStep,
            breathingPhase: breathingPhase,
            centerOffset: simd_float2(
                sin(time * 0.15) * 0.05,
                cos(time * 0.12) * 0.05
            )
        )
    }
    
    func generateColorHarmony(baseHue: Float, time: Float) -> MathematicalColorHarmony {
        let harmonicIntervals = [0.0, 0.083, 0.167, 0.25, 0.333, 0.5, 0.667, 0.75, 0.833]
        
        var harmonicColors: [simd_float3] = []
        for interval in harmonicIntervals {
            let hue = fract(baseHue + Float(interval) + time * 0.02)
            let saturation = 0.7 + sin(time * 0.3 + Float(interval) * tau) * 0.2
            let brightness = 0.8 + cos(time * 0.4 + Float(interval) * tau) * 0.2
            
            harmonicColors.append(hsvToRgb(hue: hue, saturation: saturation, value: brightness))
        }
        
        return MathematicalColorHarmony(
            primary: harmonicColors[0],
            secondary: harmonicColors[2],
            tertiary: harmonicColors[4],
            accent: harmonicColors[6],
            complement: harmonicColors[4],
            palette: harmonicColors
        )
    }
    
    func calculateSacredGeometry(time: Float) -> SacredGeometry {
        let vesicaPiscis = VesicaPiscis(
            centerA: simd_float2(-0.2, 0.0),
            centerB: simd_float2(0.2, 0.0),
            radius: 0.3 + sin(time * 0.6) * 0.1
        )
        
        let flowerOfLife = FlowerOfLife(
            center: simd_float2(0.0, 0.0),
            radius: 0.2 + cos(time * 0.4) * 0.05,
            layers: 3,
            rotation: time * 0.08
        )
        
        let metatronsCube = MetatronsCube(
            center: simd_float2(0.0, 0.0),
            scale: 0.8 + sin(time * 0.3) * 0.2,
            rotation: time * 0.05
        )
        
        return SacredGeometry(
            vesicaPiscis: vesicaPiscis,
            flowerOfLife: flowerOfLife,
            metatronsCube: metatronsCube
        )
    }
    
    private func hsvToRgb(hue: Float, saturation: Float, value: Float) -> simd_float3 {
        let chroma = value * saturation
        let secondComponent = chroma * (1 - abs(fmod(hue * 6, 2) - 1))
        let matchValue = value - chroma
        
        var rgb: simd_float3
        let hueSegment = Int(hue * 6) % 6
        
        switch hueSegment {
        case 0: rgb = simd_float3(chroma, secondComponent, 0)
        case 1: rgb = simd_float3(secondComponent, chroma, 0)
        case 2: rgb = simd_float3(0, chroma, secondComponent)
        case 3: rgb = simd_float3(0, secondComponent, chroma)
        case 4: rgb = simd_float3(secondComponent, 0, chroma)
        default: rgb = simd_float3(chroma, 0, secondComponent)
        }
        
        return rgb + simd_float3(matchValue, matchValue, matchValue)
    }
    
    private func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a * (1.0 - t) + b * t
    }
    
    private func fract(_ x: Float) -> Float {
        return x - floor(x)
    }
}

struct FractalParameters {
    let mandelbrotIterations: Int
    let juliaIterations: Int
    let juliaC: simd_float2
    let zoom: Float
    let rotation: Float
}

struct FibonacciSpiral {
    let scale: Float
    let rotation: Float
    let density: Float
    let amplitude: Float
}

struct KaleidoscopeSymmetry {
    let count: Int
    let angleStep: Float
    let breathingPhase: Float
    let centerOffset: simd_float2
}

struct MathematicalColorHarmony {
    let primary: simd_float3
    let secondary: simd_float3
    let tertiary: simd_float3
    let accent: simd_float3
    let complement: simd_float3
    let palette: [simd_float3]
}

struct SacredGeometry {
    let vesicaPiscis: VesicaPiscis
    let flowerOfLife: FlowerOfLife
    let metatronsCube: MetatronsCube
}

struct VesicaPiscis {
    let centerA: simd_float2
    let centerB: simd_float2
    let radius: Float
}

struct FlowerOfLife {
    let center: simd_float2
    let radius: Float
    let layers: Int
    let rotation: Float
}

struct MetatronsCube {
    let center: simd_float2
    let scale: Float
    let rotation: Float
}