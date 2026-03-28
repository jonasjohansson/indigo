import Metal
import CoreMedia
import IOSurface
import CSyphon

final class SyphonOutput {
    private var server: SyphonMetalServer?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue?

    var isRunning: Bool { server != nil }

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()
    }

    func start(name: String) {
        guard server == nil else { return }
        server = SyphonMetalServer(name: name, device: device, options: nil)
        if server != nil {
            print("Syphon: started server — name: \(name)")
        } else {
            print("Syphon: failed to create server")
        }
    }

    func stop() {
        server?.stop()
        server = nil
        print("Syphon: stopped")
    }

    func publishFrame(from sampleBuffer: CMSampleBuffer) {
        guard let server = server else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        guard let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else { return }
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

        let region = NSRect(x: 0, y: 0, width: Double(texture.width), height: Double(texture.height))
        server.publishFrameTexture(texture, on: commandBuffer, imageRegion: region, flipped: true)
        commandBuffer.commit()
    }
}
