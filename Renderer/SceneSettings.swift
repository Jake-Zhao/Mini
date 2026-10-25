import Foundation
import JakeCore

struct SceneSettings: Decodable {
    struct Camera: Decodable {
        let tanHalfVerticalFOV: Double, eyeHeightMetres: Double, horizonY: Double
        let halfTunnelWidthMetres: Double, ceilingHeightMetres: Double
    }
    struct Optics: Decodable {
        let exposureSeconds: Double, exposureGain: Double, bloomGain: Double, maxOutputBlurPixels: Double
        let referenceSamples: Int, productionSamples: Int
    }
    struct Materials: Decodable {let roadWetRoughness: Double}
    struct Vehicle: Decodable {let positionXMetres: Double, positionZMetres: Double, proxyWidthMetres: Double, contactY: Double}
    struct HUD: Decodable {let capHeightFraction: Double, maxWidthFraction: Double, heroCenter: [Double]}
    let camera: Camera, optics: Optics, materials: Materials, vehicle: Vehicle, hud: HUD
    init(root: URL) throws {
        self = try JSONDecoder().decode(Self.self, from: Data(contentsOf: root.appendingPathComponent("Config/scene.json")))
        guard camera.tanHalfVerticalFOV>0, camera.eyeHeightMetres>0,
              (0.3...0.85).contains(camera.horizonY), optics.exposureSeconds>=0,
              (1...33).contains(optics.referenceSamples), (1...33).contains(optics.productionSamples),
              vehicle.positionZMetres>0, vehicle.proxyWidthMetres>0, hud.heroCenter.count==2, hud.capHeightFraction>0, hud.maxWidthFraction>0 else {throw RenderError.badAsset("scene settings")}
    }
    func speedRun(_ text: String, width: Double,height: Double,metrics:[String:GlyphMetric]) throws -> GlyphRun {
        try HUDLayout.line(text,metrics:metrics,center:(width*hud.heroCenter[0],height*hud.heroCenter[1]),capHeight:height*(text == "-" ? 0.12 : hud.capHeightFraction),maxWidth:width*hud.maxWidthFraction)
    }
    func configure(_ u: inout FrameUniforms) {
        u.camera=SIMD4(Float(camera.halfTunnelWidthMetres),Float(camera.ceilingHeightMetres),Float(camera.eyeHeightMetres),Float(camera.horizonY))
        u.optics=SIMD4(Float(camera.tanHalfVerticalFOV),Float(optics.exposureGain),Float(materials.roadWetRoughness),0)
        u.vehicle=SIMD4(Float(vehicle.positionXMetres),Float(vehicle.positionZMetres),Float(vehicle.proxyWidthMetres),Float(vehicle.contactY))
    }
    func carFrame(width: Double,height: Double) -> Rect {
        var c=SceneCamera();c.tanHalfVerticalFOV=camera.tanHalfVerticalFOV;c.eyeHeight=camera.eyeHeightMetres;c.horizon=camera.horizonY
        return c.vehicleFrame(width:width,height:height,x:vehicle.positionXMetres,z:vehicle.positionZMetres,proxyWidth:vehicle.proxyWidthMetres,contactY:vehicle.contactY,textureAspect:Double(vehicle.textureWidth)/Double(vehicle.textureHeight))
    }
}
