import Metal

final class RenderTargets {
    let width: Int, height: Int
    let scene: MTLTexture
    let motion: MTLTexture
    let material: MTLTexture
    let blurred: MTLTexture
    let composed: MTLTexture
    let bloomA: MTLTexture
    let bloomB: MTLTexture
    init(device: MTLDevice, width: Int, height: Int) throws {
        self.width=max(16,width);self.height=max(16,height)
        func make(_ name:String,_ w:Int,_ h:Int)->MTLTexture? {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:max(1,w),height:max(1,h),mipmapped:false)
            d.storageMode = .private; d.usage=[.renderTarget,.shaderRead]
            let t=device.makeTexture(descriptor:d);t?.label=name;return t
        }
        guard let scene=make("01 scene linear HDR",self.width,self.height),
              let motion=make("02 shutter UV + axial depth + surface id",self.width,self.height),
              let material=make("03 roughness + wetness + object id",self.width,self.height),
              let blurred=make("04 depth-aware shutter",self.width,self.height),
              let composed=make("05 car reflection rain + spray",self.width,self.height),
              let bloomA=make("06 bloom quarter",self.width/4,self.height/4),
              let bloomB=make("07 bloom blur quarter",self.width/4,self.height/4) else {
            throw RenderError.allocation("render targets")
        }
        self.scene=scene;self.motion=motion;self.material=material
        self.blurred=blurred;self.composed=composed
        self.bloomA=bloomA;self.bloomB=bloomB
    }
}
