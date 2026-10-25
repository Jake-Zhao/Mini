import Foundation

public struct Rect: Codable, Equatable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) { self.x = x; self.y = y; self.width = width; self.height = height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
}
public struct GlyphMetric: Codable, Sendable {
    public var index: Int
    public var uv: [Double]
    public var width: Double
    public var height: Double
    public var advance: Double
}
public struct PlacedGlyph: Equatable, Sendable {
    public var text: String
    public var rect: Rect
    public var uv: Rect
}
public struct GlyphRun: Equatable, Sendable {
    public var glyphs: [PlacedGlyph]
    public var bounds: Rect
}
public enum LayoutError: Error { case missingGlyph(String), invalidMetric, invalidBounds }
public enum HUDLayout {
    public static func line(_ text: String, metrics: [String: GlyphMetric], center: (Double, Double), capHeight: Double, maxWidth: Double) throws -> GlyphRun {
        guard !text.isEmpty, capHeight.isFinite, capHeight > 0, maxWidth.isFinite, maxWidth > 0 else { throw LayoutError.invalidBounds }
        var cursor = 0.0, width = 0.0
        var items: [(String, GlyphMetric, Double)] = []
        for char in text {
            let key = String(char)
            guard let m = metrics[key] else { throw LayoutError.missingGlyph(key) }
            guard m.uv.count == 4, m.width > 0, m.height > 0, m.advance > 0 else { throw LayoutError.invalidMetric }
            items.append((key, m, cursor)); width = max(width, cursor + m.width); cursor += m.advance
        }
        let factor = min(capHeight / 320, maxWidth / width)
        let h = 320 * factor, x = center.0 - width * factor / 2, y = center.1 - h / 2
        return GlyphRun(glyphs: items.map { (key, m, pos) in
            PlacedGlyph(text: key, rect: Rect(x + pos * factor, y, m.width * factor, h), uv: Rect(m.uv[0], m.uv[1], m.uv[2], m.uv[3]))
        }, bounds: Rect(x, y, width * factor, h))
    }
    public static func speed(_ text: String, width: Double, height: Double, metrics: [String: GlyphMetric]) throws -> GlyphRun {
        try line(text, metrics: metrics, center: (width * 0.5, height * 0.5), capHeight: text == "-" ? height * 0.12 : height * 0.36, maxWidth: width * 0.59)
    }
    public static func gearBadge(speedBounds: Rect, width: Double, height: Double, avoid: Rect? = nil) -> Rect {
        let w = height * 0.110, h = height * 0.055
        let y = speedBounds.y + speedBounds.height - h * 0.70
        var x = min(width - w - height * 0.06, speedBounds.x + speedBounds.width - w * 0.35)
        if let a=avoid, y < a.y+a.height, y+h > a.y, x+w > a.x-width*0.015, x < a.x+a.width {
            x=min(x,a.x-width*0.015-w)
        }
        return Rect(max(height*0.04,x), y, w, h)
    }
    public static func car(width: Double, height: Double) -> Rect {
        SceneCamera().vehicleFrame(width: width, height: height)
    }
}
