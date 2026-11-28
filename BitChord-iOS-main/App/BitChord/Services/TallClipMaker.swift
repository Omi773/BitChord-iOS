import AVFoundation
import CoreGraphics
import Foundation

/// Makes the 3:4 lock-screen clip out of a square one.
///
/// The iPhone lock screen on iOS 26 lays a tall cover over the whole screen and takes it under
/// its own key (`MPNowPlayingInfoProperty3x4AnimatedArtwork`). Some canvas sources only have the
/// square clip; rather than leave the lock screen still, the square clip is cropped to its
/// centre 3:4 column at full height — no scaling, so no softness — and written beside it in
/// the clip cache. Made once per clip: an existing file is reused.
enum TallClipMaker {

    /// The cropped clip's file, or nil when `source` isn't a clip this can crop (no video, or
    /// narrower than 3:4 already) or the export fails. Never throws.
    static func makeTall(from source: URL) async -> URL? {
        let manager = FileManager.default
        let stem = source.deletingPathExtension().lastPathComponent
        let target = source.deletingLastPathComponent().appendingPathComponent("\(stem)-3x4.mp4")
        if manager.fileExists(atPath: target.path) { return target }

        let asset = AVURLAsset(url: source)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let natural = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform),
              let duration = try? await asset.load(.duration),
              duration.isNumeric, duration.seconds > 0
        else { return nil }

        // The picture as the viewer sees it, rotation applied.
        let upright = CGRect(origin: .zero, size: natural).applying(transform)
        let size = upright.size
        guard size.width > 0, size.height > 0 else { return nil }

        // Full height, the widest 3:4 column that fits; both even, as the encoder wants.
        let height = (size.height / 2).rounded(.down) * 2
        let width = (height * 3 / 4 / 2).rounded(.down) * 2
        guard width > 0, width <= size.width else { return nil }

        let frameRate = (try? await track.load(.nominalFrameRate)) ?? 30
        let fps = Int32(max(1, min(60, Int(frameRate.rounded()))))

        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: width, height: height)
        composition.frameDuration = CMTime(value: 1, timescale: fps)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        // Upright first, moved to the origin, then slid left so the centre column stays.
        let shift = CGAffineTransform(
            translationX: -upright.origin.x - (size.width - width) / 2,
            y: -upright.origin.y - (size.height - height) / 2)
        layer.setTransform(transform.concatenating(shift), at: .zero)
        instruction.layerInstructions = [layer]
        composition.instructions = [instruction]

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return nil
        }
        export.videoComposition = composition
        export.shouldOptimizeForNetworkUse = false

        // Written under a temporary name and moved into place, so a half-written file is never
        // taken for a finished clip.
        let partial = source.deletingLastPathComponent().appendingPathComponent("\(stem)-3x4.partial.mp4")
        try? manager.removeItem(at: partial)
        do {
            if #available(iOS 18.0, *) {
                try await export.export(to: partial, as: .mp4)
            } else {
                export.outputURL = partial
                export.outputFileType = .mp4
                await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                    export.exportAsynchronously { done.resume() }
                }
                guard export.status == .completed else {
                    try? manager.removeItem(at: partial)
                    return nil
                }
            }
            try manager.moveItem(at: partial, to: target)
            return target
        } catch {
            try? manager.removeItem(at: partial)
            return nil
        }
    }
}
