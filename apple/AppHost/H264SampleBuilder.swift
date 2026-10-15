// Mac Android Subsystem - turns scrcpy's Annex-B H.264 packets into CMSampleBuffers
// for AVSampleBufferDisplayLayer, which decodes them in hardware.
//
// Config packets carry SPS and PPS; they become the format description. Frames
// are converted from start-code framing (00 00 01 / 00 00 00 01) to the 4-byte
// length prefixes Core Media expects.
//
// Licensed under the GNU General Public License v3 or later.

import CoreMedia
import Foundation

final class H264SampleBuilder {
    private(set) var format: CMVideoFormatDescription?
    private var sps: Data?
    private var pps: Data?

    /// Returns true when the format changed (the display layer should be flushed).
    @discardableResult
    func handleConfig(_ packet: Data) -> Bool {
        var changed = false
        for nal in Self.nalUnits(in: packet) {
            guard let header = nal.first else { continue }
            switch header & 0x1f {
            case 7: if sps != nal { sps = nal; changed = true }
            case 8: if pps != nal { pps = nal; changed = true }
            default: break
            }
        }
        if changed || format == nil { rebuildFormat() }
        return changed
    }

    func sampleBuffer(for packet: Data, pts: UInt64) -> CMSampleBuffer? {
        var avcc = Data(capacity: packet.count + 16)
        for nal in Self.nalUnits(in: packet) {
            guard let header = nal.first else { continue }
            let type = header & 0x1f
            if type == 7 || type == 8 {
                // In-band parameter sets (some encoders repeat them on key frames).
                handleConfig(packet)
                continue
            }
            if type == 9 { continue } // access unit delimiter
            var length = UInt32(nal.count).bigEndian
            withUnsafeBytes(of: &length) { avcc.append(contentsOf: $0) }
            avcc.append(nal)
        }
        guard let format, !avcc.isEmpty else { return nil }

        var block: CMBlockBuffer?
        let length = avcc.count
        guard CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: length,
                                                 blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
                                                 offsetToData: 0, dataLength: length, flags: 0,
                                                 blockBufferOut: &block) == noErr, let block else { return nil }
        let copied = avcc.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: length)
        }
        guard copied == noErr else { return nil }

        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: CMTime(value: CMTimeValue(pts), timescale: 1_000_000),
                                        decodeTimeStamp: .invalid)
        var sizes = [length]
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
                                        sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
                                        sampleSizeEntryCount: 1, sampleSizeArray: &sizes,
                                        sampleBufferOut: &sample) == noErr, let sample else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }

    private func rebuildFormat() {
        guard let sps, let pps else { return }
        var description: CMVideoFormatDescription?
        let status = sps.withUnsafeBytes { spsRaw in
            pps.withUnsafeBytes { ppsRaw in
                let pointers: [UnsafePointer<UInt8>] = [
                    spsRaw.bindMemory(to: UInt8.self).baseAddress!,
                    ppsRaw.bindMemory(to: UInt8.self).baseAddress!,
                ]
                let sizes = [sps.count, pps.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault, parameterSetCount: 2, parameterSetPointers: pointers,
                    parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &description)
            }
        }
        if status == noErr { format = description }
    }

    /// Split an Annex-B byte stream into NAL units (without start codes).
    static func nalUnits(in data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var units: [Data] = []
        var start: Int? = nil
        var i = 0
        while i + 2 < bytes.count {
            if bytes[i] == 0, bytes[i + 1] == 0, bytes[i + 2] == 1 {
                if let s = start {
                    var end = i
                    if end > s, bytes[end - 1] == 0 { end -= 1 } // 4-byte start code
                    if end > s { units.append(Data(bytes[s..<end])) }
                }
                i += 3
                start = i
            } else {
                i += 1
            }
        }
        if let s = start, s < bytes.count {
            units.append(Data(bytes[s..<bytes.count]))
        } else if start == nil, !bytes.isEmpty {
            units.append(data) // no start codes: treat as one unit
        }
        return units
    }
}
