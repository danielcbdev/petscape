import AVFoundation
import Foundation
import SoundAnalysis

/// Audio analysis runs on its own actor, never the simulation/main actor or Core Audio's IO thread.
actor MusicStreamAnalyzer {
    func run(
        stream: AsyncStream<MusicAudioPacket>, sampleRate: Double,
        onScore: @escaping @Sendable (Double, Double) -> Void,
        onFailure: @escaping @Sendable () -> Void
    ) async {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            onFailure()
            return
        }
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            guard request.knownClassifications.contains("music") else {
                onFailure()
                return
            }
            request.windowDuration = CMTime(seconds: 1, preferredTimescale: 48_000)
            request.overlapFactor = 0.5
            let observer = MusicClassificationObserver(onScore: onScore, onFailure: onFailure)
            let analyzer = SNAudioStreamAnalyzer(format: format)
            try analyzer.add(request, withObserver: observer)
            defer { analyzer.removeAllRequests() }
            for await packet in stream {
                guard !Task.isCancelled else { break }
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(packet.samples.count)),
                    let destination = buffer.floatChannelData?[0]
                else {
                    onFailure()
                    break
                }
                buffer.frameLength = buffer.frameCapacity
                packet.samples.withUnsafeBufferPointer { samples in
                    if let base = samples.baseAddress { destination.update(from: base, count: samples.count) }
                }
                analyzer.analyze(buffer, atAudioFramePosition: packet.position)
            }
        } catch { onFailure() }
    }
}

/// SoundAnalysis may deliver on its own queue. Only immutable Sendable callbacks are accessed here.
nonisolated private final class MusicClassificationObserver: NSObject, SNResultsObserving {
    let onScore: @Sendable (Double, Double) -> Void
    let onFailure: @Sendable () -> Void

    init(
        onScore: @escaping @Sendable (Double, Double) -> Void,
        onFailure: @escaping @Sendable () -> Void
    ) {
        self.onScore = onScore
        self.onFailure = onFailure
    }

    func request(_ request: SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let confidence = result.classifications.first(where: { $0.identifier == "music" })?.confidence ?? 0
        // Half-overlap: count only 0.5 new seconds, not the full one-second window twice.
        onScore(confidence, result.timeRange.duration.seconds * 0.5)
    }

    func request(_ request: SNRequest, didFailWithError error: any Error) { onFailure() }
    func requestDidComplete(_ request: SNRequest) {}
}
