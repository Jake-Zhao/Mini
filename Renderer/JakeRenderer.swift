import Foundation
import Metal
import MetalKit
import UIKit
import QuartzCore
import JakeCore

final class JakeRenderer: NSObject, MTKViewDelegate {
    let mailbox: TelemetryMailbox
    var options = RenderOptions()
    var onError: ((String) -> Void)?
    var onReport: ((GPUReport) -> Void)?
    private(set) var quality = RenderQuality.high
    private let device: MTLDevice, queue: MTLCommandQueue, textures: TextureStore
    private let pso: [String: MTLRenderPipelineState]
    private let particleStep: MTLComputePipelineState
    private let particles: MTLBuffer
    private let metrics: [String: GlyphMetric]
    private let settings: SceneSettings
    private var targets: RenderTargets?
    private var lastTime: CFTimeInterval?
    private var clock = MotionClock()
    private var frameID: UInt64 = 0
    private var frameSlot = 0
    private let inFlight = DispatchSemaphore(value: 3)
    private var uniforms: [MTLBuffer] = [], glyphBuffers: [MTLBuffer] = []
    private var captureRequest: ((Result<URL,Error>) -> Void)?
    private var runtimeStopped = false
    private let clearBloom: MTLTexture
    private let material: [MTLTexture], environment: [MTLTexture], glyphAtlas: MTLTexture
    private var lastEpoch: UInt64?

    init(view: MTKView, mailbox: TelemetryMailbox) throws {
        guard let device = view.device, let queue = device.makeCommandQueue(), let library = device.makeDefaultLibrary() else { throw RenderError.deviceUnavailable }
        self.device = device; self.queue = queue; self.mailbox = mailbox
        let store = try TextureStore(device: device, queue: queue)
        textures = store
        settings = try SceneSettings(root: store.root)
        metrics = try JSONDecoder().decode([String: GlyphMetric].self, from: Data(contentsOf: store.root.appendingPathComponent("Config/glyphs.json")))
        material = try ["asphalt_color","asphalt_surface","concrete_color","concrete_surface","flow_noise"].map { try store.require($0) }
        environment = try ["car_body","brake_emission","brake_halo","binary_glyphs","flow_noise","contact_shadow"].map { try store.require($0) }
        glyphAtlas = try store.require("glyph_atlas")
        precondition(MemoryLayout<FrameUniforms>.stride == 224)
        precondition(MemoryLayout<SpriteInstance>.stride == 48 && MemoryLayout<SprayParticle>.stride == 32)
        func pipeline(_ fragment: String, _ formats: [MTLPixelFormat], vertex: String = "fullscreenVertex", blend: Bool = false) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor(); d.label = fragment
            guard let v = library.makeFunction(name: vertex), let f = library.makeFunction(name: fragment) else { throw RenderError.missing(fragment) }
            d.vertexFunction = v; d.fragmentFunction = f
            for (i,format) in formats.enumerated() {
                let a = d.colorAttachments[i]!; a.pixelFormat = format
                if blend {
                    a.isBlendingEnabled = true; a.rgbBlendOperation = .add; a.alphaBlendOperation = .add
                    a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .oneMinusSourceAlpha
                    a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                }
            }
            return try device.makeRenderPipelineState(descriptor: d)
        }
        pso = [
            "scene": try pipeline("sceneFragment",[.rgba16Float,.rgba16Float,.rgba16Float]),
            "motion": try pipeline("motionBlurFragment",[.rgba16Float]),
            "focus": try pipeline("focusDepthFragment",[.rgba16Float]),
            "environment": try pipeline("environmentFragment",[.rgba16Float]),
            "bloom": try pipeline("bloomExtractFragment",[.rgba16Float]),
            "bloomH": try pipeline("bloomHorizontalFragment",[.rgba16Float]),
            "bloomV": try pipeline("bloomVerticalFragment",[.rgba16Float]),
            "output": try pipeline("outputFragment",[.bgra8Unorm_srgb]),
            "spray": try pipeline("sprayFragment",[.rgba16Float],vertex:"sprayVertex",blend:true),
            "accent": try pipeline("accentFragment",[.bgra8Unorm_srgb],blend:true),
            "glyph": try pipeline("glyphFragment",[.bgra8Unorm_srgb],vertex:"glyphVertex",blend:true),
            "badge": try pipeline("badgeFragment",[.bgra8Unorm_srgb],blend:true)
        ]
        guard let function = library.makeFunction(name:"advanceSpray") else { throw RenderError.missing("advanceSpray") }
        particleStep = try device.makeComputePipelineState(function:function)
        var seed: UInt64 = 0x4a414b45
        func random() -> Float { seed = seed &* 6364136223846793005 &+ 1; return Float((seed >> 33) & 0xffff)/65535 }
        let initial = (0..<384).map { _ -> SprayParticle in
            let s = SIMD4(random(),random(),random(),random())
            return SprayParticle(position: SIMD4(5.5+s.x*1.4,0.015+s.y*0.15,7.5+s.z*2.5,1),seed:s)
        }
        guard let pb = device.makeBuffer(bytes: initial, length: initial.count*MemoryLayout<SprayParticle>.stride, options:.storageModeShared) else { throw RenderError.allocation("particles") }
        particles = pb; particles.label = "GPU water spray instances"
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:1,height:1,mipmapped:false); td.storageMode = .shared; td.usage = .shaderRead
        guard let black = device.makeTexture(descriptor:td) else { throw RenderError.allocation("black bloom") }
        var zero = [UInt16](repeating:0,count:4)
        zero.withUnsafeBytes { black.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:8) }
        clearBloom = black
        super.init()
        for i in 0..<3 {
            guard let a = device.makeBuffer(length:256,options:.storageModeShared), let b = device.makeBuffer(length:16*MemoryLayout<SpriteInstance>.stride,options:.storageModeShared) else { throw RenderError.allocation("frame ring") }
            a.label="Uniform ring \(i)";b.label="Glyph ring \(i)";uniforms.append(a);glyphBuffers.append(b)
        }
        view.colorPixelFormat = .bgra8Unorm_srgb; view.depthStencilPixelFormat = .invalid
        view.framebufferOnly = false
        view.preferredFramesPerSecond = 60; view.enableSetNeedsDisplay = false
        view.clearColor = MTLClearColor(red:0.002,green:0.004,blue:0.003,alpha:1)
        view.delegate = self
    }
    func setActive(_ active: Bool, view: MTKView) { lastTime = nil; view.isPaused = !active; runtimeStopped = !active }
    func resetMotion() { lastTime = nil; clock.reset() }
    func requestScreenshot(_ completion: @escaping (Result<URL,Error>) -> Void) { captureRequest = completion }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { lastTime = nil; targets = nil }

    private func effectiveQuality() -> RenderQuality {
        let process = ProcessInfo.processInfo
        let thermal: ThermalLevel
        switch process.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .serious
        }
        if options.automaticQuality || thermal == .serious || thermal == .critical { return .automatic(thermal, lowPower:process.isLowPowerModeEnabled) }
        return options.manualQuality
    }

    func draw(in view: MTKView) {
        guard !runtimeStopped, view.drawableSize.width>1,view.drawableSize.height>1 else { return }
        guard inFlight.wait(timeout:.now()) == .success else { return }
        guard let drawable = view.currentDrawable, let command = queue.makeCommandBuffer() else { inFlight.signal();lastTime=nil;return }
        do {
            let q = effectiveQuality(); quality=q; view.preferredFramesPerSecond=q.fps
            let w=Double(drawable.texture.width),h=Double(drawable.texture.height)
            let bw=max(16,Int(w*q.scale)),bh=max(16,Int(h*q.scale))
            if targets?.width != bw || targets?.height != bh { targets=try RenderTargets(device:device,width:bw,height:bh);lastTime=nil }
            guard let t=targets else { throw RenderError.allocation("targets") }

            let now=CACurrentMediaTime(), dt=lastTime.map{now-$0} ?? 0; lastTime=now
            let snapshot=mailbox.read();let hud=snapshot.resolve(at:now)
            if lastEpoch != snapshot.epoch {clock.reset();lastEpoch=snapshot.epoch}
            let m=clock.advance(dt:dt,speedKph:hud.speedKph,paused:options.paused,reducedMotion:options.reducedMotion)
            let run=try settings.speedRun(hud.speedText,width:w,height:h,metrics:metrics)
            let badge=HUDLayout.gearBadge(speedBounds:run.bounds,width:w,height:h,avoid:settings.carFrame(width:w,height:h))
            let gear=try HUDLayout.line(hud.gearText,metrics:metrics,center:(badge.midX,badge.midY),capHeight:h*0.046,maxWidth:badge.width*0.77)

            var u=FrameUniforms();settings.configure(&u);u.viewport=SIMD4(Float(bw),Float(bh),Float(w),Float(h))
            let visualMPS = options.reducedMotion ? 0 : (hud.speedKph ?? 0)/3.6
            u.travel=SIMD4(Float(m.wrappedMetres),Float(visualMPS),Float(m.deltaMetres),Float(m.deltaTime))
            let phase=DistancePhase.phases(clock.distanceMetres)
            u.phaseA=SIMD4(phase[0][0],phase[0][1],phase[0][2],phase[0][3])
            u.phaseB=SIMD4(phase[1][0],phase[1][1],phase[1][2],phase[1][3])
            u.phaseC=SIMD4(phase[2][0],phase[2][1],phase[2][2],phase[2][3])
            u.sampling=SIMD4(options.referenceExposure ? Float(settings.optics.referenceSamples):Float(min(q.blurTaps,settings.optics.productionSamples)),1,0,0)
            u.effects=SIMD4(Float(settings.optics.exposureSeconds),Float(settings.optics.maxOutputBlurPixels*q.scale),q.bloomEnabled ? Float(settings.optics.bloomGain):0,Float(q.particleCount))
            u.flags=SIMD4(hud.brakeOn ? 1:0,visualMPS > 0 ? 1:0,options.debugMode,hud.speedKph == nil ? 0:1)
            u.carRect=normalized(settings.carFrame(width:w,height:h),width:w,height:h)
            u.heroRect=normalized(run.bounds,width:w,height:h)
            u.tuning=SIMD4(Float(q.blurTaps),options.cinematicDepth ? 0.45:0,options.rainEnabled ? 1:0,options.carEnabled ? 1:0)

            let slot=frameSlot
            let ub=uniforms[slot], gb=glyphBuffers[slot]
            withUnsafeBytes(of:&u){ub.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
            var sprites: [SpriteInstance] = []
            for glyph in run.glyphs + gear.glyphs {
                let color: SIMD4<Float> = glyph.text == "D" ? SIMD4(0.35,0.90,0.56,1):SIMD4(1,1,1,1)
                sprites.append(SpriteInstance(rect:normalized(glyph.rect,width:w,height:h),uvRect:SIMD4(Float(glyph.uv.x),Float(glyph.uv.y),Float(glyph.uv.width),Float(glyph.uv.height)),color:color))
            }
            guard sprites.count<=16 else { throw RenderError.badAsset("too many HUD glyphs") }
            sprites.withUnsafeBytes { gb.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count) }

            command.label="Jake frame \(frameID)"
            if m.active && options.carEnabled && q.particleCount>0 {
                guard let e=command.makeComputeCommandEncoder() else { throw RenderError.allocation("particle encoder") }
                e.label="Water spray GPU update";e.setComputePipelineState(particleStep);e.setBuffer(particles,offset:0,index:0);e.setBuffer(ub,offset:0,index:1)
                let size=min(particleStep.maxTotalThreadsPerThreadgroup,64)
                e.dispatchThreads(MTLSize(width:384,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:size,height:1,depth:1));e.endEncoding()
            }

            try pass(command,"scene",outputs:[t.scene,t.motion,t.material],uniform:ub,inputs:material)
            try pass(command,"motion",outputs:[t.blurred],uniform:ub,inputs:[t.scene,t.motion])
            if options.cinematicDepth { try pass(command,"focus",outputs:[t.scene],uniform:ub,inputs:[t.blurred,t.motion]) }
            try pass(command,"environment",outputs:[t.composed],uniform:ub,inputs:[options.cinematicDepth ? t.scene:t.blurred]+environment)

            if visualMPS > 0 && options.carEnabled && q.particleCount>0 {
                let rp=descriptor([t.composed],load:.load)
                guard let e=command.makeRenderCommandEncoder(descriptor:rp),let state=pso["spray"] else { throw RenderError.pipeline("spray") }
                e.setRenderPipelineState(state);e.setVertexBuffer(ub,offset:0,index:0);e.setVertexBuffer(particles,offset:0,index:1)
                e.setFragmentBuffer(ub,offset:0,index:0);e.setFragmentTexture(environment[0],index:0);e.setFragmentTexture(t.motion,index:1)
                e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,instanceCount:q.particleCount);e.endEncoding()
            }

            if q.bloomEnabled {
                try pass(command,"bloom",outputs:[t.bloomA],uniform:ub,inputs:[t.composed])
                try pass(command,"bloomH",outputs:[t.bloomB],uniform:ub,inputs:[t.bloomA])
                try pass(command,"bloomV",outputs:[t.bloomA],uniform:ub,inputs:[t.bloomB])
            }
            try pass(command,"output",outputs:[drawable.texture],uniform:ub,inputs:[t.composed,q.bloomEnabled ? t.bloomA:clearBloom,t.motion,t.material])

            if options.hudEnabled && options.debugMode == 0 {
                let rp=descriptor([drawable.texture],load:.load)
                guard let e=command.makeRenderCommandEncoder(descriptor:rp),let accent=pso["accent"],let glyph=pso["glyph"],let badgePSO=pso["badge"] else { throw RenderError.pipeline("HUD") }
                e.label="Sharp HUD, native resolution"
                e.setRenderPipelineState(accent);e.setFragmentBuffer(ub,offset:0,index:0);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
                var rect=normalized(badge,width:w,height:h)
                e.setRenderPipelineState(badgePSO);e.setFragmentBytes(&rect,length:MemoryLayout<SIMD4<Float>>.stride,index:0);e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
                e.setRenderPipelineState(glyph);e.setVertexBuffer(gb,offset:0,index:0);e.setVertexBuffer(ub,offset:0,index:1);e.setFragmentTexture(glyphAtlas,index:0)
                e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,instanceCount:sprites.count);e.endEncoding()
            }

            if let callback=captureRequest {captureRequest=nil;try capture(command:command,texture:drawable.texture,callback:callback)}
            let sem=inFlight; let report=onReport; let count=frameID;frameID &+= 1
            command.addCompletedHandler { buffer in
                sem.signal()
                let elapsed=buffer.gpuEndTime>buffer.gpuStartTime ? (buffer.gpuEndTime-buffer.gpuStartTime)*1000:nil
                if let err=buffer.error { DispatchQueue.main.async { [weak self] in self?.onError?(err.localizedDescription) } }
                if count%60 == 0 { DispatchQueue.main.async {report?(GPUReport(gpuMilliseconds:elapsed,quality:q,framesSubmitted:count))} }
            }
            command.present(drawable);command.commit();frameSlot=(frameSlot+1)%3
        } catch {
            inFlight.signal();lastTime=nil;onError?(error.localizedDescription)
        }
    }

    private func descriptor(_ outputs:[MTLTexture],load:MTLLoadAction = .clear) -> MTLRenderPassDescriptor {
        let rp=MTLRenderPassDescriptor()
        for (index,t) in outputs.enumerated() {
            let a=rp.colorAttachments[index]!
            a.texture=t;a.loadAction=load;a.storeAction = .store
            a.clearColor=MTLClearColor(red:0,green:0,blue:0,alpha:1)
        }
        return rp
    }

    private func pass(_ cb:MTLCommandBuffer,_ key:String,outputs:[MTLTexture],uniform:MTLBuffer,inputs:[MTLTexture]) throws {
        guard let state=pso[key],let e=cb.makeRenderCommandEncoder(descriptor:descriptor(outputs)) else {throw RenderError.pipeline(key)}
        e.label=key;e.setRenderPipelineState(state);e.setFragmentBuffer(uniform,offset:0,index:0)
        for(i,t)in inputs.enumerated(){e.setFragmentTexture(t,index:i)}
        e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);e.endEncoding()
    }

    private func capture(command:MTLCommandBuffer,texture:MTLTexture,callback:@escaping(Result<URL,Error>)->Void) throws {
        let row=((texture.width*4+255)/256)*256,count=row*texture.height
        guard let buffer=device.makeBuffer(length:count,options:.storageModeShared),let blit=command.makeBlitCommandEncoder() else {throw RenderError.allocation("screenshot")}
        blit.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:texture.width,height:texture.height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:row,destinationBytesPerImage:count)
        blit.endEncoding();let width=texture.width,height=texture.height
        command.addCompletedHandler { cb in
            if let err=cb.error {DispatchQueue.main.async{callback(.failure(err))};return}
            let data=Data(bytes:buffer.contents(),count:count)
            DispatchQueue.main.async {
                do {
                    guard let provider=CGDataProvider(data:data as CFData),
                          let colorSpace=CGColorSpace(name:CGColorSpace.sRGB),
                          let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:row,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent),
                          let png=UIImage(cgImage:image).pngData() else {throw RenderError.badAsset("screenshot image")}
                    let url=FileManager.default.temporaryDirectory.appendingPathComponent("Jake-Metal-\(UUID().uuidString).png")
                    try png.write(to:url);callback(.success(url))
                } catch {callback(.failure(error))}
            }
        }
    }
}
