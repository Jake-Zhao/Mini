import Foundation

public enum Origin: String, Codable, Sendable { case demo, live, replay }
public enum Quality: String, Codable, Sendable { case valid, stale, unavailable, unsupported, malformed }
public struct Reading<T: Equatable & Sendable>: Equatable, Sendable {
    public var value: T
    public var time: Double
    public var epoch: UInt64
    public var origin: Origin
    public var quality: Quality
    public init(_ value: T, time: Double, epoch: UInt64, origin: Origin, quality: Quality = .valid) {
        self.value = value; self.time = time; self.epoch = epoch; self.origin = origin; self.quality = quality
    }
    public func isFresh(now: Double, epoch: UInt64, origin: Origin, ttl: Double) -> Bool {
        let age = now - time
        return quality == .valid && self.epoch == epoch && self.origin == origin && age.isFinite && age >= 0 && age <= ttl
    }
}
public enum Gear: Equatable, Sendable {
    case unknown, park, reverse, neutral, drive, forward(Int)
    public var text: String {
        switch self {
        case .unknown: return "-"
        case .park: return "P"
        case .reverse: return "R"
        case .neutral: return "N"
        case .drive: return "D"
        case .forward(let n): return (1...10).contains(n) ? "D\(n)" : "-"
        }
    }
}
public enum Brake: Equatable, Sendable { case unknown, released, pressed }
public struct Telemetry: Sendable {
    public var epoch: UInt64
    public var origin: Origin
    public var speed: Reading<Double>?
    public var gear: Reading<Gear>?
    public var brake: Reading<Brake>?
    public init(epoch: UInt64 = 1, origin: Origin = .demo, speed: Reading<Double>? = nil, gear: Reading<Gear>? = nil, brake: Reading<Brake>? = nil) {
        self.epoch = epoch; self.origin = origin; self.speed = speed; self.gear = gear; self.brake = brake
    }
    public func resolve(at now: Double) -> HUDState {
        let v = speed.flatMap { reading -> Double? in
            guard reading.isFresh(now: now, epoch: epoch, origin: origin, ttl: 1.5), reading.value.isFinite, (0...255).contains(reading.value) else { return nil }
            return reading.value
        }
        let g = gear.flatMap { $0.isFresh(now: now, epoch: epoch, origin: origin, ttl: 1.0) ? $0.value : nil } ?? .unknown
        let b = brake.flatMap { $0.isFresh(now: now, epoch: epoch, origin: origin, ttl: 0.25) ? $0.value : nil } ?? .unknown
        return HUDState(speedKph: v, gear: g, brake: b, origin: origin)
    }
}
public struct HUDState: Equatable, Sendable {
    public let speedKph: Double?
    public let gear: Gear
    public let brake: Brake
    public let origin: Origin
    public init(speedKph: Double?, gear: Gear, brake: Brake, origin: Origin) {
        self.speedKph = speedKph; self.gear = gear; self.brake = brake; self.origin = origin
    }
    public var speedText: String { speedKph.map { String(Int($0.rounded())) } ?? "-" }
    public var gearText: String { gear.text }
    public var brakeOn: Bool { brake == .pressed }
}
public final class TelemetryMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var telemetry = Telemetry()
    public init() {}
    public func publish(_ value: Telemetry) { lock.lock(); telemetry = value; lock.unlock() }
    public func read() -> Telemetry { lock.lock(); defer { lock.unlock() }; return telemetry }
}
