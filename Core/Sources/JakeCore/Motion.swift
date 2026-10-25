import Foundation

public struct MotionFrame: Equatable, Sendable {
    public let wrappedMetres: Double
    public let deltaMetres: Double
    public let metresPerSecond: Double
    public let deltaTime: Double
    public let active: Bool
}
public struct MotionClock: Sendable {
    public private(set) var distanceMetres: Double = 0
    public init() {}
    public mutating func advance(dt: Double, speedKph: Double?, paused: Bool, reducedMotion: Bool) -> MotionFrame {
        guard !paused, !reducedMotion, dt.isFinite, dt > 0, dt <= 0.5,
              let speedKph, speedKph.isFinite, speedKph > 0, speedKph <= 255 else {
            return MotionFrame(wrappedMetres: distanceMetres.truncatingRemainder(dividingBy: 76800), deltaMetres: 0, metresPerSecond: 0, deltaTime: 0, active: false)
        }
        let mps = speedKph / 3.6, delta = mps * dt
        distanceMetres += delta
        return MotionFrame(wrappedMetres: distanceMetres.truncatingRemainder(dividingBy: 76800), deltaMetres: delta, metresPerSecond: mps, deltaTime: dt, active: true)
    }
    public mutating func reset() { distanceMetres = 0 }
}
public enum ThermalLevel: String, Sendable { case nominal, fair, serious, critical }
public struct RenderQuality: Equatable, Sendable {
    public let scale: Double
    public let fps: Int
    public let blurTaps: Int
    public let particleCount: Int
    public let bloomEnabled: Bool
    public static let high = RenderQuality(scale: 0.82, fps: 60, blurTaps: 13, particleCount: 384, bloomEnabled: true)
    public static let balanced = RenderQuality(scale: 0.68, fps: 60, blurTaps: 9, particleCount: 192, bloomEnabled: true)
    public static let cool = RenderQuality(scale: 0.55, fps: 30, blurTaps: 5, particleCount: 64, bloomEnabled: false)
    public static let critical = RenderQuality(scale: 0.50, fps: 30, blurTaps: 3, particleCount: 0, bloomEnabled: false)
    public static func automatic(_ thermal: ThermalLevel, lowPower: Bool) -> RenderQuality {
        switch thermal {
        case .critical: return .critical
        case .serious: return .cool
        case .fair: return lowPower ? .cool : .balanced
        case .nominal: return lowPower ? .balanced : .high
        }
    }
}
public enum DemoCycle {
    public static func sample(time: Double, epoch: UInt64 = 1) -> Telemetry {
        let t = max(0, time).truncatingRemainder(dividingBy: 40)
        let v: Double, g: Gear, b: Brake
        switch t {
        case 0..<3: v = 0; g = .drive; b = .pressed
        case 3..<8: v = (t - 3) * 8; g = .forward(t < 5 ? 1 : 2); b = .released
        case 8..<14: v = 40 + (t - 8) * 7; g = .forward(t < 11 ? 3 : 4); b = .released
        case 14..<18: v = 82 + (t - 14) * 4.5; g = .forward(5); b = .released
        case 18..<27: v = 100; g = .forward(6); b = .released
        case 27..<36: v = max(0, 100 - (t - 27) * 100 / 9); g = .forward(t < 31 ? 4 : 2); b = .pressed
        default: v = 0; g = .drive; b = .pressed
        }
        return Telemetry(epoch: epoch, origin: .demo,
            speed: Reading(v, time: time, epoch: epoch, origin: .demo),
            gear: Reading(g, time: time, epoch: epoch, origin: .demo),
            brake: Reading(b, time: time, epoch: epoch, origin: .demo))
    }
}
public enum BinaryMessage {
    public static let phrase = "一路平安"
    public static let bytes = Array(phrase.utf8)
    public static let bits: [UInt8] = bytes.flatMap { byte in (0..<8).reversed().map { (byte >> $0) & 1 } }
}
