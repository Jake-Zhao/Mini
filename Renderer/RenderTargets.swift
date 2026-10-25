import Metal

final class RenderTargets {
    let width: Int, height: Int
    let scene: MTLTexture, motion: MTLTexture, blurred: MTLTexture, composed: MTLTexture
    let bloomA: MTLTexture, bloomB: MTLTexture
    init(device: MTLDevice, width: Int, height: Int) throws {
        self.width = max(16,width); self.height = max(16,height)
        func make(_ name: String, _ w: Int, _ h: Int) throws -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: max(1,w), height: max(1,h), mipmapped: false)
            d.storageMode = .private; d.usage = [.renderTarget,.shaderRead]
            guard let t = device.makeTexture(descriptor: d) else { throw RenderError.allocation(name) }; t.label = name; return t
        }
        scene = try make("01 scene linear HDR",self.width,self.height)
        motion = try make("02 shutter UV displacement + axial metres + surface",self.width,self.height)
        blurred = try make("03 depth-aware shutter",self.width,self.height)
        composed = try make("04 car reflection rain + spray",self.width,self.height)
        bloomA = try make("05 bloom quarter",self.width/4,self.height/4)
        bloomB = try make("06 bloom blur quarter",self.width/4,self.height/4)
    }
}
