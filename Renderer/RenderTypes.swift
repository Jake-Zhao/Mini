import Foundation
import Metal
import JakeCore

struct FrameUniforms {
    var viewport = SIMD4<Float>(repeating: 0)
    var travel = SIMD4<Float>(repeating: 0)
    var camera = SIMD4<Float>(7.8,4.8,0.78,0.70)
    var effects = SIMD4<Float>(0.010,32,0.12,384)
    var flags = SIMD4<Float>(0,0,0,1)
    var carRect = SIMD4<Float>(repeating: 0)
    var heroRect = SIMD4<Float>(repeating: 0)
    var tuning = SIMD4<Float>(9,0,1,1)
    var optics = SIMD4<Float>(0.50,1.0,0.13,0)
    var phaseA = SIMD4<Float>(repeating: 0)
    var phaseB = SIMD4<Float>(repeating: 0)
    var phaseC = SIMD4<Float>(repeating: 0)
    var vehicle = SIMD4<Float>(6.8,10.5,3.8,0.920)
    var sampling = SIMD4<Float>(9,1,0,0)
}
struct SpriteInstance {
    var rect: SIMD4<Float>
    var uvRect: SIMD4<Float>
    var color: SIMD4<Float>
}
struct SprayParticle {
    var position: SIMD4<Float>
    var seed: SIMD4<Float>
}
struct RenderOptions: Equatable {
    var paused = false
    var cinematicDepth = false
    var referenceExposure = false
    var reducedMotion = false
    var automaticQuality = true
    var manualQuality = RenderQuality.high
    var rainEnabled = true
    var carEnabled = true
    var hudEnabled = true
    var debugMode: Float = 0
}
struct GPUReport {
    var gpuMilliseconds: Double?
    var quality: RenderQuality
    var framesSubmitted: UInt64
}
func normalized(_ rect: Rect, width: Double, height: Double) -> SIMD4<Float> {
    SIMD4(Float(rect.x/width),Float(rect.y/height),Float(rect.width/width),Float(rect.height/height))
}
