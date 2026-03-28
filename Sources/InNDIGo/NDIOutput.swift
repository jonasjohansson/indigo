import CoreMedia
import CoreVideo
import CNDI

final class NDIOutput {
    // NDI sender instance.
    private var sender: NDIlib_send_instance_t?
    private var isRunning = false

    func start(name: String) {
        guard NDIlib_initialize() else {
            print("NDI: Failed to initialize")
            return
        }

        name.withCString { ptr in
            var createSettings = NDIlib_send_create_t()
            createSettings.p_ndi_name = ptr
            createSettings.p_groups = nil
            createSettings.clock_video = true
            createSettings.clock_audio = true
            sender = NDIlib_send_create(&createSettings)
        }

        if sender != nil {
            isRunning = true
            print("NDI: started — name: \(name)")
        } else {
            print("NDI: Failed to create sender")
            NDIlib_destroy()
        }
    }

    func stop() {
        if let sender = sender {
            NDIlib_send_destroy(sender)
        }
        sender = nil
        NDIlib_destroy()
        isRunning = false
        print("NDI: stopped")
    }

    func sendVideoFrame(from sampleBuffer: CMSampleBuffer) {
        guard isRunning, let sender = sender, let pixelBuffer = sampleBuffer.imageBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var frame = NDIlib_video_frame_v2_t()
        frame.xres = Int32(width)
        frame.yres = Int32(height)
        frame.FourCC = NDIlib_FourCC_video_type_BGRA
        frame.frame_rate_N = 60000
        frame.frame_rate_D = 1000
        frame.picture_aspect_ratio = 0
        frame.frame_format_type = NDIlib_frame_format_type_progressive
        frame.timecode = NDIlib_send_timecode_synthesize
        frame.p_data = baseAddress.assumingMemoryBound(to: UInt8.self)
        frame.line_stride_in_bytes = Int32(bytesPerRow)
        frame.p_metadata = nil
        frame.timestamp = 0
        NDIlib_send_send_video_v2(sender, &frame)
    }

    func sendAudioFrame(from sampleBuffer: CMSampleBuffer) {
        guard isRunning, let sender = sender else { return }
        guard let blockBuffer = sampleBuffer.dataBuffer else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let data = dataPointer else { return }
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }

        let channelCount = Int(asbd.mChannelsPerFrame)
        let sampleCount = length / (channelCount * MemoryLayout<Float>.size)

        // Deinterleave: ScreenCaptureKit delivers interleaved float32,
        // NDI v2 expects planar float32
        let planarBuffer = UnsafeMutablePointer<Float>.allocate(capacity: sampleCount * channelCount)
        defer { planarBuffer.deallocate() }

        let interleaved = UnsafePointer<Float>(OpaquePointer(data))
        for ch in 0..<channelCount {
            for s in 0..<sampleCount {
                planarBuffer[ch * sampleCount + s] = interleaved[s * channelCount + ch]
            }
        }

        var audioFrame = NDIlib_audio_frame_v2_t()
        audioFrame.sample_rate = Int32(asbd.mSampleRate)
        audioFrame.no_channels = Int32(channelCount)
        audioFrame.no_samples = Int32(sampleCount)
        audioFrame.timecode = NDIlib_send_timecode_synthesize
        audioFrame.p_data = planarBuffer
        audioFrame.channel_stride_in_bytes = Int32(sampleCount * MemoryLayout<Float>.size)
        audioFrame.p_metadata = nil
        audioFrame.timestamp = 0
        NDIlib_send_send_audio_v2(sender, &audioFrame)
    }
}
