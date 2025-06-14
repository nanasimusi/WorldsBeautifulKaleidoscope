import Foundation
import simd
import CoreGraphics

class ColorScienceEngine {
    static let shared = ColorScienceEngine()
    
    private let displayP3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    
    private var culturalPalettes: [String: CulturalPalette] = [:]
    private var currentCulturalContext: String = "universal"
    
    private init() {
        setupCulturalPalettes()
    }
    
    private func setupCulturalPalettes() {
        culturalPalettes["japanese"] = CulturalPalette(
            name: "Japanese Harmony",
            primaryHues: [0.0, 0.083, 0.25, 0.5, 0.75],
            culturalMeaning: ["red": "life", "orange": "happiness", "green": "nature", "blue": "purity", "purple": "nobility"],
            seasonalAdaptation: true
        )
        
        culturalPalettes["scandinavian"] = CulturalPalette(
            name: "Nordic Minimalism",
            primaryHues: [0.0, 0.17, 0.5, 0.67, 0.83],
            culturalMeaning: ["red": "warmth", "yellow": "light", "blue": "tranquility", "teal": "nature", "white": "purity"],
            seasonalAdaptation: true
        )
        
        culturalPalettes["universal"] = CulturalPalette(
            name: "Universal Harmony",
            primaryHues: [0.0, 0.083, 0.167, 0.25, 0.333, 0.5, 0.667, 0.75, 0.833],
            culturalMeaning: [:],
            seasonalAdaptation: false
        )
        
        culturalPalettes["accessibility"] = CulturalPalette(
            name: "High Contrast",
            primaryHues: [0.0, 0.17, 0.33, 0.5, 0.67, 0.83],
            culturalMeaning: [:],
            seasonalAdaptation: false
        )
    }
    
    func generateAdaptivePalette(time: Float, emotionalState: EmotionalState, accessibility: AccessibilitySettings) -> AdaptivePalette {
        let culturalPalette = culturalPalettes[currentCulturalContext] ?? culturalPalettes["universal"]!
        
        var adaptedHues: [Float] = []
        for baseHue in culturalPalette.primaryHues {
            let timeShift = sin(time * 0.1) * 0.05
            let emotionalShift = getEmotionalHueShift(emotionalState: emotionalState)
            let adaptedHue = fract(baseHue + timeShift + emotionalShift)
            adaptedHues.append(adaptedHue)
        }
        
        let colors = adaptedHues.map { hue in
            generateDisplayP3Color(
                hue: hue,
                saturation: getSaturationForAccessibility(accessibility: accessibility),
                brightness: getBrightnessForAccessibility(accessibility: accessibility),
                time: time
            )
        }
        
        return AdaptivePalette(
            colors: colors,
            culturalContext: currentCulturalContext,
            emotionalResonance: emotionalState,
            accessibilityCompliance: accessibility,
            temporalPhase: time
        )
    }
    
    private func generateDisplayP3Color(hue: Float, saturation: Float, brightness: Float, time: Float) -> simd_float4 {
        let dynamicSaturation = saturation + sin(time * 0.3 + hue * 2 * Float.pi) * 0.1
        let dynamicBrightness = brightness + cos(time * 0.2 + hue * 2 * Float.pi) * 0.05
        
        let hsvColor = simd_float3(hue, dynamicSaturation, dynamicBrightness)
        let rgbColor = hsvToRgb(hsv: hsvColor)
        
        let displayP3Color = convertSrgbToDisplayP3(srgb: rgbColor)
        
        return simd_float4(displayP3Color.x, displayP3Color.y, displayP3Color.z, 1.0)
    }
    
    private func convertSrgbToDisplayP3(srgb: simd_float3) -> simd_float3 {
        let srgbToXyz = float3x3(
            simd_float3(0.4124564, 0.3575761, 0.1804375),
            simd_float3(0.2126729, 0.7151522, 0.0721750),
            simd_float3(0.0193339, 0.1191920, 0.9503041)
        )
        
        let xyzToDisplayP3 = float3x3(
            simd_float3(2.4934969, -0.9313836, -0.4027108),
            simd_float3(-0.8294890, 1.7626641, 0.0236247),
            simd_float3(0.0358458, -0.0761724, 0.9568845)
        )
        
        let linearSrgb = srgbToLinear(srgb: srgb)
        let xyz = srgbToXyz * linearSrgb
        let linearDisplayP3 = xyzToDisplayP3 * xyz
        let displayP3 = linearToDisplayP3(linear: linearDisplayP3)
        
        return clamp(displayP3, min: simd_float3(0), max: simd_float3(1))
    }
    
    private func srgbToLinear(srgb: simd_float3) -> simd_float3 {
        return simd_float3(
            srgb.x <= 0.04045 ? srgb.x / 12.92 : pow((srgb.x + 0.055) / 1.055, 2.4),
            srgb.y <= 0.04045 ? srgb.y / 12.92 : pow((srgb.y + 0.055) / 1.055, 2.4),
            srgb.z <= 0.04045 ? srgb.z / 12.92 : pow((srgb.z + 0.055) / 1.055, 2.4)
        )
    }
    
    private func linearToDisplayP3(linear: simd_float3) -> simd_float3 {
        return simd_float3(
            linear.x <= 0.0030186 ? linear.x * 12.92 : 1.055 * pow(linear.x, 1.0/2.4) - 0.055,
            linear.y <= 0.0030186 ? linear.y * 12.92 : 1.055 * pow(linear.y, 1.0/2.4) - 0.055,
            linear.z <= 0.0030186 ? linear.z * 12.92 : 1.055 * pow(linear.z, 1.0/2.4) - 0.055
        )
    }
    
    func generateColorHarmony(baseColor: simd_float4, harmonyType: ColorHarmonyType, time: Float) -> ScienceColorHarmony {
        let baseHue = rgbToHsv(rgb: simd_float3(baseColor.x, baseColor.y, baseColor.z)).x
        
        var harmonicHues: [Float] = []
        
        switch harmonyType {
        case .monochromatic:
            harmonicHues = [baseHue, baseHue, baseHue, baseHue, baseHue]
        case .analogous:
            harmonicHues = [baseHue, baseHue + 0.083, baseHue + 0.167, baseHue - 0.083, baseHue - 0.167]
        case .complementary:
            harmonicHues = [baseHue, baseHue + 0.5, baseHue + 0.167, baseHue + 0.333, baseHue + 0.667]
        case .triadic:
            harmonicHues = [baseHue, baseHue + 0.333, baseHue + 0.667, baseHue + 0.111, baseHue + 0.556]
        case .tetradic:
            harmonicHues = [baseHue, baseHue + 0.25, baseHue + 0.5, baseHue + 0.75, baseHue + 0.125]
        case .splitComplementary:
            harmonicHues = [baseHue, baseHue + 0.417, baseHue + 0.583, baseHue + 0.167, baseHue + 0.833]
        }
        
        let harmonicColors = harmonicHues.map { hue in
            generateDisplayP3Color(hue: fract(hue), saturation: 0.8, brightness: 0.9, time: time)
        }
        
        return ScienceColorHarmony(
            type: harmonyType,
            colors: harmonicColors,
            baseHue: baseHue,
            temporalEvolution: time
        )
    }
    
    func calculateColorContrast(color1: simd_float4, color2: simd_float4) -> Float {
        let luminance1 = calculateRelativeLuminance(color: color1)
        let luminance2 = calculateRelativeLuminance(color: color2)
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private func calculateRelativeLuminance(color: simd_float4) -> Float {
        let linear = srgbToLinear(srgb: simd_float3(color.x, color.y, color.z))
        return 0.2126 * linear.x + 0.7152 * linear.y + 0.0722 * linear.z
    }
    
    func validateAccessibilityCompliance(palette: [simd_float4], standards: AccessibilityStandards) -> AccessibilityReport {
        var violations: [AccessibilityViolation] = []
        let minimumContrast: Float = standards.level == .AAA ? 7.0 : 4.5
        
        for i in 0..<palette.count {
            for j in (i+1)..<palette.count {
                let contrast = calculateColorContrast(color1: palette[i], color2: palette[j])
                if contrast < minimumContrast {
                    violations.append(AccessibilityViolation(
                        type: .insufficientContrast,
                        colorPair: (palette[i], palette[j]),
                        measuredContrast: contrast,
                        requiredContrast: minimumContrast
                    ))
                }
            }
        }
        
        return AccessibilityReport(
            compliant: violations.isEmpty,
            violations: violations,
            overallScore: max(0, 1.0 - Float(violations.count) / Float(palette.count * (palette.count - 1) / 2)),
            recommendations: generateAccessibilityRecommendations(violations: violations)
        )
    }
    
    private func generateAccessibilityRecommendations(violations: [AccessibilityViolation]) -> [String] {
        var recommendations: [String] = []
        
        if !violations.isEmpty {
            recommendations.append("Increase brightness difference between similar colors")
            recommendations.append("Consider using high-contrast mode for better accessibility")
            recommendations.append("Add pattern or texture differentiation for color-blind users")
        }
        
        return recommendations
    }
    
    private func getEmotionalHueShift(emotionalState: EmotionalState) -> Float {
        switch emotionalState {
        case .energetic: return 0.05
        case .calm: return -0.03
        case .creative: return 0.08
        case .focused: return 0.0
        case .joyful: return 0.12
        case .meditative: return -0.05
        }
    }
    
    private func getSaturationForAccessibility(accessibility: AccessibilitySettings) -> Float {
        return accessibility.highContrast ? 1.0 : 0.8
    }
    
    private func getBrightnessForAccessibility(accessibility: AccessibilitySettings) -> Float {
        return accessibility.highContrast ? 0.9 : 0.7
    }
    
    func setCulturalContext(_ context: String) {
        currentCulturalContext = context
    }
    
    private func hsvToRgb(hsv: simd_float3) -> simd_float3 {
        let chroma = hsv.z * hsv.y
        let secondComponent = chroma * (1 - abs(fmod(hsv.x * 6, 2) - 1))
        let matchValue = hsv.z - chroma
        
        var rgb: simd_float3
        let hueSegment = Int(hsv.x * 6) % 6
        
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
    
    private func rgbToHsv(rgb: simd_float3) -> simd_float3 {
        let maxVal = max(rgb.x, max(rgb.y, rgb.z))
        let minVal = min(rgb.x, min(rgb.y, rgb.z))
        let delta = maxVal - minVal
        
        var hue: Float = 0
        if delta > 0 {
            if maxVal == rgb.x {
                hue = fmod((rgb.y - rgb.z) / delta, 6) / 6
            } else if maxVal == rgb.y {
                hue = ((rgb.z - rgb.x) / delta + 2) / 6
            } else {
                hue = ((rgb.x - rgb.y) / delta + 4) / 6
            }
        }
        
        let saturation = maxVal == 0 ? 0 : delta / maxVal
        let value = maxVal
        
        return simd_float3(hue < 0 ? hue + 1 : hue, saturation, value)
    }
    
    private func fract(_ x: Float) -> Float {
        return x - floor(x)
    }
}

struct CulturalPalette {
    let name: String
    let primaryHues: [Float]
    let culturalMeaning: [String: String]
    let seasonalAdaptation: Bool
}

struct AdaptivePalette {
    let colors: [simd_float4]
    let culturalContext: String
    let emotionalResonance: EmotionalState
    let accessibilityCompliance: AccessibilitySettings
    let temporalPhase: Float
}

struct ScienceColorHarmony {
    let type: ColorHarmonyType
    let colors: [simd_float4]
    let baseHue: Float
    let temporalEvolution: Float
}

struct AccessibilityReport {
    let compliant: Bool
    let violations: [AccessibilityViolation]
    let overallScore: Float
    let recommendations: [String]
}

struct AccessibilityViolation {
    let type: AccessibilityViolationType
    let colorPair: (simd_float4, simd_float4)
    let measuredContrast: Float
    let requiredContrast: Float
}

enum EmotionalState {
    case energetic, calm, creative, focused, joyful, meditative
}

enum ColorHarmonyType {
    case monochromatic, analogous, complementary, triadic, tetradic, splitComplementary
}

enum AccessibilityViolationType {
    case insufficientContrast, colorBlindnessIssue
}

struct AccessibilitySettings {
    let highContrast: Bool
    let colorBlindSupport: Bool
    let motionReduction: Bool
}

struct AccessibilityStandards {
    let level: AccessibilityLevel
}

enum AccessibilityLevel {
    case AA, AAA
}