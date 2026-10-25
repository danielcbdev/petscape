import AVFoundation
import CoreAudio
import Foundation
import PetScapeCore

/// Captures only outgoing system audio via the public macOS 14.2 tap API. Never microphone or screens.
/// Samples are copied into a bounded stream for an isolated analyzer; nothing is written or logged.
public final class SystemMusicScoreSource: MusicScoreSource {
    public var onScore: ((Double, Double) -> Void)?
    public var onFailure: (() -> Void)?
    private var tap: AudioObjectID = 0
    private var device: AudioObjectID = 0
    private var ioProc: AudioDeviceIOProcID?
    private var continuation: AsyncStream<MusicAudioPacket>.Continuation?
    private var analysisTask: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var lastResult = ContinuousClock.now
    private var generation = 0
    private var routeListener: AudioObjectPropertyListenerBlock?
    private var formatListener: AudioObjectPropertyListenerBlock?
    private var routeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
    }

    public init() {}

    public func start() throws {
        stop()
        guard #available(macOS 14.2, *) else { throw MusicCaptureError.unavailable }
        do {
            let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
            description.name = "PetScape music detection"
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try check(AudioHardwareCreateProcessTap(description, &tap))
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var format = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            try check(AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format))
            guard format.mFormatID == kAudioFormatLinearPCM,
                format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32,
                format.mSampleRate.isFinite, format.mSampleRate > 0,
                format.mChannelsPerFrame > 0, format.mChannelsPerFrame <= 2
            else { throw MusicCaptureError.unavailable }
            let specification: [String: Any] = [
                kAudioAggregateDeviceNameKey: "PetScape music detection",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapUIDKey: description.uuid.uuidString,
                        kAudioSubTapDriftCompensationKey: true,
                    ]
                ],
            ]
            try check(AudioHardwareCreateAggregateDevice(specification as CFDictionary, &device))
            let (stream, sink) = AsyncStream<MusicAudioPacket>.makeStream(bufferingPolicy: .bufferingNewest(8))
            continuation = sink
            let channels = Int(format.mChannelsPerFrame)
            let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
            // Concurrency: Core Audio owns its IO thread. The callback captures only a Sendable stream
            // continuation and immutable format scalars, never actor-isolated state or borrowed buffers.
            let callback: AudioDeviceIOBlock = { @Sendable _, input, timestamp, _, _ in
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let first = buffers.first, let data = first.mData else { return }
                let stride = interleaved ? channels : 1
                let count = Int(first.mDataByteSize) / MemoryLayout<Float>.size / stride
                guard count > 0, count <= 16_384 else { return }
                let source = data.assumingMemoryBound(to: Float.self)
                var mono = [Float](repeating: 0, count: count)
                if interleaved {
                    for frame in 0..<count {
                        var value: Float = 0
                        for channel in 0..<channels { value += source[frame * channels + channel] }
                        mono[frame] = value / Float(channels)
                    }
                } else {
                    guard buffers.count == channels else { return }
                    for buffer in buffers {
                        guard let data = buffer.mData, Int(buffer.mDataByteSize) >= count * 4 else { return }
                        let samples = data.assumingMemoryBound(to: Float.self)
                        for frame in 0..<count { mono[frame] += samples[frame] / Float(channels) }
                    }
                }
                let position = timestamp.pointee.mSampleTime
                guard position.isFinite, position >= 0, position < Double(Int64.max),
                    timestamp.pointee.mFlags.contains(.sampleTimeValid)
                else { return }
                sink.yield(MusicAudioPacket(samples: mono, position: Int64(position)))
            }
            try check(AudioDeviceCreateIOProcIDWithBlock(&ioProc, device, nil, callback))
            let token = generation
            let sampleRate = format.mSampleRate
            let listener: AudioObjectPropertyListenerBlock = { @Sendable [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.onFailure?()
                }
            }
            var outputAddress = routeAddress
            try check(
                AudioObjectAddPropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject), &outputAddress, nil, listener))
            routeListener = listener
            try check(AudioObjectAddPropertyListenerBlock(tap, &address, nil, listener))
            formatListener = listener
            analysisTask = Task { [weak self] in
                let analyzer = MusicStreamAnalyzer()
                await analyzer.run(stream: stream, sampleRate: sampleRate) { [weak self] confidence, duration in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.lastResult = .now
                        self.onScore?(confidence, duration)
                    }
                } onFailure: { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        self.onFailure?()
                    }
                }
            }
            lastResult = .now
            try check(AudioDeviceStart(device, ioProc))
            // Detect a missing/stalled stream without a simulation-frame poll or storing audio history.
            watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    guard let self, self.generation == token else { return }
                    if self.lastResult.duration(to: .now) > .seconds(5) {
                        self.onFailure?()
                        return
                    }
                }
            }
        } catch {
            stop()
            throw MusicCaptureError.unavailable
        }
    }

    public func stop() {
        generation += 1
        if let routeListener {
            var outputAddress = routeAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &outputAddress, nil, routeListener)
        }
        routeListener = nil
        if let formatListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            AudioObjectRemovePropertyListenerBlock(tap, &address, nil, formatListener)
        }
        formatListener = nil
        watchdog?.cancel()
        watchdog = nil
        if let ioProc {
            AudioDeviceStop(device, ioProc)
            AudioDeviceDestroyIOProcID(device, ioProc)
        }
        ioProc = nil
        continuation?.finish()
        continuation = nil
        analysisTask?.cancel()
        analysisTask = nil
        if device != 0 { AudioHardwareDestroyAggregateDevice(device) }
        device = 0
        if #available(macOS 14.2, *), tap != 0 { AudioHardwareDestroyProcessTap(tap) }
        tap = 0
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            Log.permissions.error("Core Audio operation failed with OSStatus \(status, privacy: .public)")
            throw MusicCaptureError.unavailable
        }
    }

    isolated deinit { stop() }
}

nonisolated struct MusicAudioPacket: Sendable {
    let samples: [Float]
    let position: Int64
}
