import XCTest
@testable import JakeCore

final class TelemetryTests: XCTestCase {
    func make(_ v: Double = 72) -> Telemetry {
        Telemetry(epoch:2,origin:.live,speed:Reading(v,time:10,epoch:2,origin:.live),gear:Reading(.forward(3),time:10,epoch:2,origin:.live),brake:Reading(.pressed,time:10,epoch:2,origin:.live))
    }
    func testFreshSpeed() { XCTAssertEqual(make().resolve(at:10.2).speedText,"72") }
    func testStaleSpeed() { XCTAssertNil(make().resolve(at:11.51).speedKph) }
    func testFutureTimestampRejected() { XCTAssertNil(make().resolve(at:9.99).speedKph) }
    func testWrongEpochRejected() { var t=make();t.epoch=3;XCTAssertNil(t.resolve(at:10.1).speedKph) }
    func testWrongOriginRejected() { var t=make();t.origin = .demo;XCTAssertNil(t.resolve(at:10.1).speedKph) }
    func testMalformedRejected() { var t=make();t.speed?.quality = .malformed;XCTAssertNil(t.resolve(at:10.1).speedKph) }
    func testNonfiniteAndRangeRejected() { for v in [Double.nan,Double.infinity,-1,256] { XCTAssertNil(make(v).resolve(at:10).speedKph) } }
    func testZeroIsValid() { XCTAssertEqual(make(0).resolve(at:10).speedText,"0") }
    func testByteMaximumIsValid() { XCTAssertEqual(make(255).resolve(at:10).speedText,"255") }
    func testUnknownGearNeverGuessed() { var t=make();t.gear=nil;XCTAssertEqual(t.resolve(at:10).gearText,"-") }
    func testDriveDoesNotBecomeD3() { var t=make();t.gear?.value = .drive;XCTAssertEqual(t.resolve(at:10).gearText,"D") }
    func testBrakeExpiresBeforeSpeed() { XCTAssertFalse(make().resolve(at:10.251).brakeOn);XCTAssertEqual(make().resolve(at:10.251).speedText,"72") }
    func testStoppedBrakeCanStillLight() { XCTAssertTrue(make(0).resolve(at:10.1).brakeOn) }
    func testUnknownSpeedDoesNotFabricateBrakeRelease() { var t=make();t.speed=nil;XCTAssertTrue(t.resolve(at:10.1).brakeOn) }
    func testUnknownBrakeIsOff() { var t=make();t.brake=nil;XCTAssertFalse(t.resolve(at:10.1).brakeOn) }
    func testInvalidForwardGearIsUnknown() { XCTAssertEqual(Gear.forward(0).text,"-");XCTAssertEqual(Gear.forward(11).text,"-") }
    func testMailboxRoundtrip() { let box=TelemetryMailbox();box.publish(make());XCTAssertEqual(box.read().resolve(at:10).speedText,"72") }
}
final class MotionTests: XCTestCase {
    func integrate(_ speed:Double,_ rate:Int) -> Double {
        var c=MotionClock();for _ in 0..<rate*10 {_=c.advance(dt:1/Double(rate),speedKph:speed,paused:false,reducedMotion:false)};return c.distanceMetres
    }
    func testPhysicalHundred() { XCTAssertEqual(integrate(100,60),100/3.6*10,accuracy:1e-7) }
    func testFiveTimesDistance() { XCTAssertEqual(integrate(100,60)/integrate(20,60),5,accuracy:1e-7) }
    func testFrameRateIndependence() { XCTAssertEqual(integrate(72,30),integrate(72,120),accuracy:1e-7) }
    func testZeroStopsImmediately() {var c=MotionClock();_=c.advance(dt:0.02,speedKph:100,paused:false,reducedMotion:false);let d=c.distanceMetres;let m=c.advance(dt:0.02,speedKph:0,paused:false,reducedMotion:false);XCTAssertEqual(c.distanceMetres,d);XCTAssertEqual(m.metresPerSecond,0)}
    func testPausedStops() {var c=MotionClock();let m=c.advance(dt:0.02,speedKph:100,paused:true,reducedMotion:false);XCTAssertFalse(m.active);XCTAssertEqual(c.distanceMetres,0)}
    func testReducedMotionStops() {var c=MotionClock();let m=c.advance(dt:0.02,speedKph:100,paused:false,reducedMotion:true);XCTAssertFalse(m.active)}
    func testMissingSpeedStops() {var c=MotionClock();XCTAssertFalse(c.advance(dt:0.02,speedKph:nil,paused:false,reducedMotion:false).active)}
    func testResumeGapNotIntegrated() {var c=MotionClock();XCTAssertFalse(c.advance(dt:5,speedKph:100,paused:false,reducedMotion:false).active);XCTAssertEqual(c.distanceMetres,0)}
    func testBadDeltaRejected() {for dt in [-1.0,Double.nan,Double.infinity,0] {var c=MotionClock();XCTAssertFalse(c.advance(dt:dt,speedKph:100,paused:false,reducedMotion:false).active)}}
    func testWrappedTravelKeepsAbsoluteDistance() {var c=MotionClock();for _ in 0..<150000 {_=c.advance(dt:0.02,speedKph:100,paused:false,reducedMotion:false)};let m=c.advance(dt:0.02,speedKph:100,paused:false,reducedMotion:false);XCTAssertGreaterThan(c.distanceMetres,76800);XCTAssertLessThan(m.wrappedMetres,76800)}
    func testThermalCriticalLimits() {let q=RenderQuality.automatic(.critical,lowPower:false);XCTAssertEqual(q.particleCount,0);XCTAssertEqual(q.fps,30);XCTAssertFalse(q.bloomEnabled)}
    func testLowPowerDownshifts() {XCTAssertLessThan(RenderQuality.automatic(.nominal,lowPower:true).scale,RenderQuality.high.scale)}
    func testDemoHasOnlyDemoOrigin() {let t=DemoCycle.sample(time:21);XCTAssertEqual(t.origin,.demo);XCTAssertEqual(t.speed?.value,100);XCTAssertEqual(t.gear?.value,.forward(6))}
    func testDemoZeroHoldsBrake() {let t=DemoCycle.sample(time:38);XCTAssertEqual(t.speed?.value,0);XCTAssertEqual(t.brake?.value,.pressed)}
    func testSafeJourneyEncodingReversible() {
        let b=BinaryMessage.bits;XCTAssertEqual(b.count,96);XCTAssertTrue(b.allSatisfy{$0==0||$0==1})
        let bytes=stride(from:0,to:b.count,by:8).map { start in b[start..<start+8].reduce(UInt8(0)){($0<<1)|$1} }
        XCTAssertEqual(String(bytes:bytes,encoding:.utf8),"一路平安")
    }
}
final class ProtocolTests: XCTestCase {
    func testArbitraryELMSplits() throws {let payload=Array("41 0D 48\r>".utf8);for split in 0...payload.count {var f=ELMPromptFramer();let a=try f.append(Array(payload[..<split]));let b=try f.append(Array(payload[split...]));XCTAssertEqual(a+b,[Array("41 0D 48\r".utf8)])}}
    func testMultiplePrompts() throws {var f=ELMPromptFramer();XCTAssertEqual(try f.append(Array("OK>41 0D 00>".utf8)).count,2)}
    func testOverflowResets() throws {var f=ELMPromptFramer(limit:3);XCTAssertThrowsError(try f.append([1,2,3,4]));XCTAssertEqual(try f.append(Array("OK>".utf8)),[Array("OK".utf8)])}
    func testSpeedDecode() throws {XCTAssertEqual(try StandardSpeedDecoder.decode(payload:[0x41,0x0D,0x48]),72)}
    func testWrongResponseRejected() {XCTAssertThrowsError(try StandardSpeedDecoder.decode(payload:[0x41,0x0C,0x48]))}
    func testMissingPayloadRejected() {XCTAssertThrowsError(try StandardSpeedDecoder.decode(payload:[0x41,0x0D]))}
    func testSupportBitmap() throws {XCTAssertEqual(try StandardSpeedDecoder.supportedPIDs(base:0,payload:[0x41,0,0,8,0,0]),Set([UInt8(13)]))}
}
final class LayoutTests: XCTestCase {
    func metrics() throws -> [String:GlyphMetric] {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode([String:GlyphMetric].self,from:Data(contentsOf:root.appendingPathComponent("Resources/Config/glyphs.json")))
    }
    func testAllSpeedValuesCentredAndBounded() throws {
        let m=try metrics();for v in 0...255 {let r=try HUDLayout.speed(String(v),width:2556,height:1179,metrics:m);XCTAssertEqual(r.bounds.midX,1278,accuracy:1e-7);XCTAssertEqual(r.bounds.midY,589.5,accuracy:1e-7);XCTAssertLessThanOrEqual(r.bounds.width,2556*0.59+1e-6)}
    }
    func testThreeDigitsNoFallbackFont() throws {let r=try HUDLayout.speed("100",width:1774,height:887,metrics:metrics());XCTAssertEqual(r.glyphs.map(\.text),["1","0","0"])}
    func testAllAtlasUVsStayInBounds() throws {for m in try metrics().values {XCTAssertEqual(m.uv.count,4);XCTAssertGreaterThanOrEqual(m.uv[0],0);XCTAssertLessThanOrEqual(m.uv[0]+m.uv[2],1);XCTAssertLessThanOrEqual(m.uv[1]+m.uv[3],1)}}
    func testUnknownSymbolFailsExplicitly() throws {XCTAssertThrowsError(try HUDLayout.line("X",metrics:metrics(),center:(0,0),capHeight:100,maxWidth:500))}
    func testCarPreservesAspect() {let c=HUDLayout.car(width:2556,height:1179);XCTAssertEqual(c.width/c.height,1050.0/655.0,accuracy:1e-9);XCTAssertLessThan(c.width,2556*0.25)}
    func testGearDoesNotDisplaceSpeed() throws {let r=try HUDLayout.speed("72",width:1774,height:887,metrics:metrics());let b=HUDLayout.gearBadge(speedBounds:r.bounds,width:1774,height:887);XCTAssertEqual(r.bounds.midX,887,accuracy:1e-8);XCTAssertLessThan(b.width,r.bounds.width*0.25);XCTAssertLessThan(b.x+b.width,1774)}
}
