import Foundation
import Metal

struct TextureAsset: Decodable {
    let name: String
    let runtime: String
    let size: [Int]
    let srgb: Bool
    let mipmaps: Bool
    let encoding: String
}
enum RenderError: LocalizedError {
    case deviceUnavailable, missing(String), badAsset(String), pipeline(String), allocation(String)
    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: return "此设备未提供可用的 Metal 设备。"
        case .missing(let s): return "缺少必需资源：\(s)"
        case .badAsset(let s): return "资源格式错误：\(s)"
        case .pipeline(let s): return "Metal 管线创建失败：\(s)"
        case .allocation(let s): return "GPU 资源分配失败：\(s)"
        }
    }
}
final class TextureStore {
    let root: URL
    private(set) var textures: [String: MTLTexture] = [:]
    init(device: MTLDevice, queue: MTLCommandQueue, bundle: Bundle = .main) throws {
        guard let root = bundle.resourceURL else { throw RenderError.missing("App resources") }
        self.root = root
        let manifest = try JSONDecoder().decode([TextureAsset].self, from: Data(contentsOf: root.appendingPathComponent("Config/assets.json")))
        let command = queue.makeCommandBuffer()
        let blit = command?.makeBlitCommandEncoder()
        guard let command, let blit else { throw RenderError.allocation("mipmap command") }
        for asset in manifest {
            let bytes = try Data(contentsOf: root.appendingPathComponent(asset.runtime))
            guard bytes.count >= 12, ([Array("JTX1".utf8), Array("JTX2".utf8)].contains(Array(bytes.prefix(4)))) else { throw RenderError.badAsset(asset.name) }
            func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | (Int(bytes[offset + $1]) << ($1 * 8)) } }
            let w = u32(4), h = u32(8)
            let halfFloat = Array(bytes.prefix(4)) == Array("JTX2".utf8)
            let bytesPerPixel = halfFloat ? 8 : 4
            guard halfFloat == (asset.encoding == "linear-premultiplied-f16"), !halfFloat || !asset.srgb else { throw RenderError.badAsset(asset.name) }
            guard w > 0, h > 0, w <= 8192, h <= 8192, bytes.count == 12 + w * h * bytesPerPixel,
                  asset.size == [w,h] else { throw RenderError.badAsset(asset.name) }
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: halfFloat ? .rgba16Float : (asset.srgb ? .rgba8Unorm_srgb : .rgba8Unorm), width: w, height: h, mipmapped: asset.mipmaps)
            desc.usage = [.shaderRead]; desc.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: desc) else { throw RenderError.allocation(asset.name) }
            texture.label = asset.name
            bytes.withUnsafeBytes { raw in
                texture.replace(region: MTLRegionMake2D(0,0,w,h), mipmapLevel: 0, withBytes: raw.baseAddress!.advanced(by: 12), bytesPerRow: w * bytesPerPixel)
            }
            if asset.mipmaps { blit.generateMipmaps(for: texture) }
            textures[asset.name] = texture
        }
        blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
    }
    func require(_ name: String) throws -> MTLTexture {
        guard let value = textures[name] else { throw RenderError.missing(name) }; return value
    }
}
