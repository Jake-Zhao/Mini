import Foundation

public struct SceneCamera: Sendable {
    public var tanHalfVerticalFOV: Double = 0.30
    public var eyeHeight: Double = 1.22
    public var horizon: Double = 0.61
    public init() {}
    public func project(x: Double, y: Double, z: Double, aspect: Double) -> (Double, Double)? {
        guard x.isFinite, y.isFinite, z.isFinite, z > 0, aspect.isFinite, aspect > 0 else { return nil }
        return (0.5 + x / (2 * tanHalfVerticalFOV * aspect * z),
                horizon - (y-eyeHeight) / (2*tanHalfVerticalFOV*z))
    }
    public func groundPoint(u: Double, v: Double, aspect: Double) -> (Double, Double)? {
        guard v > horizon, aspect > 0 else { return nil }
        let z = eyeHeight / ((v-horizon)*2*tanHalfVerticalFOV)
        return ((u-0.5)*2*tanHalfVerticalFOV*aspect*z, z)
    }
    public func shutterVelocity(x: Double, y: Double, z: Double, aspect: Double, speedMPS: Double, exposure: Double) -> (Double, Double)? {
        guard speedMPS >= 0, exposure >= 0,
              let p=project(x:x,y:y,z:z,aspect:aspect),
              let q=project(x:x,y:y,z:z+speedMPS*exposure,aspect:aspect) else {return nil}
        return (p.0-q.0,p.1-q.1)
    }
    public func vehicleFrame(width: Double, height: Double,
                             x: Double = 3.50, z: Double = 8.00,
                             proxyWidth: Double = 1.65, contactY: Double = 0.920, textureAspect: Double = 1400.0/521.0) -> Rect {
        guard width.isFinite, height.isFinite, width>0, height>0,
              proxyWidth.isFinite, proxyWidth>0, textureAspect.isFinite, textureAspect>0 else {return Rect(0,0,0,0)}
        let aspect=width/height
        guard let foot=project(x:x,y:0,z:z,aspect:aspect) else {return Rect(0,0,0,0)}
        let w=proxyWidth/(2*tanHalfVerticalFOV*aspect*z)*width
        let h=w/textureAspect
        return Rect(foot.0*width-w*0.52,foot.1*height-h*contactY,w,h)
    }
}

public enum DistancePhase {
    public static func unit(_ metres: Double, period: Double) -> Double {
        guard metres.isFinite, period.isFinite, period>0 else {return 0}
        let r=metres.truncatingRemainder(dividingBy:period)/period
        return r<0 ? r+1:r
    }
    public static func phases(_ metres: Double) -> [[Float]] {
        [
            [8,12,3,1.5].map{Float(unit(metres,period:$0))},
            [24,16,7,6].map{Float(unit(metres,period:$0))},
            [76800,800,400,96].map{Float(unit(metres,period:$0))}
        ]
    }
}
