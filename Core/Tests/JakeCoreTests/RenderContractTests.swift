import XCTest
@testable import JakeCore

final class RenderContractTests: XCTestCase {
    func testSlowVisibleFrameKeepsPhysicalDistance() { var c=MotionClock();_=c.advance(dt:0.20,speedKph:72,paused:false,reducedMotion:false);XCTAssertEqual(c.distanceMetres,4,accuracy:1e-12) }
    func testProjectionGroundRoundTrip() throws {
        let c=SceneCamera()
        for aspect in [2.0,2556.0/1179.0] {for z in [3.0,10.5,40,120] {for x in [-6.0,0,6.8] {
            let uv=try XCTUnwrap(c.project(x:x,y:0,z:z,aspect:aspect))
            let p=try XCTUnwrap(c.groundPoint(u:uv.0,v:uv.1,aspect:aspect))
            XCTAssertEqual(p.0,x,accuracy:1e-9);XCTAssertEqual(p.1,z,accuracy:1e-9)
        }}}
    }
    func testRejectBehindCamera() {XCTAssertNil(SceneCamera().project(x:0,y:0,z:-1,aspect:2))}
    func testCarGroundRegistration() throws {
        let c=SceneCamera();let f=c.vehicleFrame(width:1774,height:887)
        let uv=try XCTUnwrap(c.project(x:4.30,y:0,z:10.00,aspect:2))
        XCTAssertEqual((f.y+f.height*0.820)/887,uv.1,accuracy:1e-10)
        XCTAssertEqual((f.x+f.width*0.52)/1774,uv.0,accuracy:1e-10)
    }
    func testShutterDoesNotDependOnFrameRate() throws {
        let c=SceneCamera();var results:[Double]=[]
        for _ in [30,60,120] {let m=try XCTUnwrap(c.shutterVelocity(x:4,y:0,z:10,aspect:2,speedMPS:100/3.6,exposure:0.0125));results.append(m.0)}
        XCTAssertEqual(results[0],results[1]);XCTAssertEqual(results[1],results[2])
    }
    func testExposureZeroIsSharp() throws {let v=try XCTUnwrap(SceneCamera().shutterVelocity(x:5,y:0,z:10,aspect:2,speedMPS:0,exposure:0.0125));XCTAssertEqual(v.0,0);XCTAssertEqual(v.1,0)}
    func testNearFieldMovesFaster() throws {
        let c=SceneCamera();let near=try XCTUnwrap(c.shutterVelocity(x:3,y:0,z:6,aspect:2,speedMPS:20,exposure:0.0125));let far=try XCTUnwrap(c.shutterVelocity(x:3,y:0,z:50,aspect:2,speedMPS:20,exposure:0.0125));XCTAssertGreaterThan(abs(near.0),abs(far.0))
    }
    func testOpticalFlowPointsAwayFromVanishingPoint() throws {
        let c=SceneCamera();let r=try XCTUnwrap(c.shutterVelocity(x:5,y:0,z:10,aspect:2,speedMPS:20,exposure:0.0125));XCTAssertGreaterThan(r.0,0);XCTAssertGreaterThan(r.1,0)
    }
    func testIndependentMaterialPhases() {
        let a=DistancePhase.phases(76799.999),b=DistancePhase.phases(76800.001)
        for row in 0..<3 {for col in 0..<4 {let d=abs(a[row][col]-b[row][col]);XCTAssertLessThan(min(d,1-d),0.002)}}
    }
    func testLargeDistancePhasePrecision() {let d=1_000_000_000.125;XCTAssertEqual(DistancePhase.unit(d,period:8),0.015625,accuracy:1e-12)}
    func testPhaseInputGuard() {XCTAssertEqual(DistancePhase.unit(.nan,period:8),0);XCTAssertEqual(DistancePhase.unit(3,period:0),0)}
    func testBrakeAndParkAreIndependent() {let t=Telemetry(epoch:1,origin:.live,speed:Reading(0,time:0,epoch:1,origin:.live),gear:Reading(.park,time:0,epoch:1,origin:.live),brake:nil);XCTAssertEqual(t.resolve(at:0).brake,.unknown)}
    func testGearExcludesVehicleWithoutMovingSpeed() {
        let a = 2556.0/1179.0
        let w=500*a,h=500.0,car=SceneCamera().vehicleFrame(width:w,height:h)
        let hero=Rect(w*0.205,h*0.32,w*0.59,h*0.36)
        let g=HUDLayout.gearBadge(speedBounds:hero,width:w,height:h,avoid:car)
        let separated = g.x+g.width <= car.x || car.x+car.width <= g.x || g.y+g.height <= car.y || car.y+car.height <= g.y
        XCTAssertTrue(separated)
        XCTAssertEqual(hero.midX,w*0.5,accuracy:0.00001)
    }
}