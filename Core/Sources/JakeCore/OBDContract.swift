import Foundation

public enum OBDInputError: Error, Equatable { case overflow, malformed, notSupported, ambiguousECU }
public struct ELMPromptFramer {
    public var limit: Int
    private var bytes: [UInt8] = []
    public init(limit: Int = 16384) { self.limit = limit }
    public mutating func reset() { bytes.removeAll(keepingCapacity: true) }
    public mutating func append(_ input: [UInt8]) throws -> [[UInt8]] {
        var frames: [[UInt8]] = []
        for b in input {
            if b == 62 { if !bytes.isEmpty { frames.append(bytes) }; reset() }
            else { guard bytes.count < limit else { reset(); throw OBDInputError.overflow }; bytes.append(b) }
        }
        return frames
    }
}
public enum StandardSpeedDecoder {
    public static func decode(payload: [UInt8]) throws -> Double {
        guard payload.count >= 3, payload[0] == 0x41, payload[1] == 0x0D else { throw OBDInputError.malformed }
        return Double(payload[2])
    }
    public static func supportedPIDs(base: UInt8, payload: [UInt8]) throws -> Set<UInt8> {
        guard payload.count == 6, payload[0] == 0x41, payload[1] == base else { throw OBDInputError.malformed }
        let mask = payload[2...5].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        return Set((0..<32).compactMap { n in
            let pid = Int(base) + n + 1
            return pid <= 255 && (mask & (1 << (31 - n))) != 0 ? UInt8(pid) : nil
        })
    }
}
public protocol LiveTelemetrySource: Sendable {
    func start() async throws
    func snapshots() -> AsyncStream<Telemetry>
    func stop() async
}
