// Assemble a folder of PNG frames into an MP4 (H.264) with AVFoundation.
// Usage: swift frames_to_mp4.swift <frames_glob_dir> <prefix> <fps> <out.mp4>
import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 5 || args.count == 6 else {
    FileHandle.standardError.write("usage: frames_to_mp4 <dir> <prefix> <fps> <out.mp4> [bitrate]\n".data(using:.utf8)!)
    exit(2)
}
let dir = args[1], prefix = args[2]
let fps = Int32(args[3]) ?? 30
let outPath = args[4]
let bitrate = args.count > 5 ? (Int(args[5]) ?? 12_000_000) : 12_000_000

let fm = FileManager.default
let files = (try! fm.contentsOfDirectory(atPath: dir))
    .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".png") }
    .sorted()
guard !files.isEmpty else { FileHandle.standardError.write("no frames\n".data(using:.utf8)!); exit(1) }

// size from first frame
let first = NSImage(contentsOfFile: "\(dir)/\(files[0])")!
let w = Int(first.representations[0].pixelsWide)
let h = Int(first.representations[0].pixelsHigh)

let outURL = URL(fileURLWithPath: outPath)
try? fm.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let settings: [String:Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: w,
    AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let attrs: [String:Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
    kCVPixelBufferWidthKey as String: w,
    kCVPixelBufferHeightKey as String: h
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func pixelBuffer(_ img: NSImage) -> CVPixelBuffer {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pb)
    let buf = pb!
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: w, height: h,
                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    var rect = CGRect(x: 0, y: 0, width: w, height: h)
    let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    ctx.draw(cg, in: rect)
    CVPixelBufferUnlockBaseAddress(buf, [])
    return buf
}

var frame: Int64 = 0
for f in files {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    let img = NSImage(contentsOfFile: "\(dir)/\(f)")!
    let pb = pixelBuffer(img)
    let t = CMTime(value: frame, timescale: fps)
    adaptor.append(pb, withPresentationTime: t)
    frame += 1
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("wrote \(outPath): \(files.count) frames @ \(fps)fps, \(w)x\(h)")
