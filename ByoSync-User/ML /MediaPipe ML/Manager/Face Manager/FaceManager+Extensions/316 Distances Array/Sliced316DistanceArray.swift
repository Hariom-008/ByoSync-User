//
//  SliceDistanceArray.swift
//  ML-Testing
//

import Foundation

extension FaceManager {

    /// Returns up to 80 frames, each with exactly 316 distances (indices 0...315)
    func save316LengthDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 80 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 80.")
            return []
        }

        let first80Frames = AllFramesOptionalAndMandatoryDistance.prefix(80)

        let trimmed = first80Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            // Take exactly 316 values: indices 0...315
            return Array(frame[0..<316])
        }

        print("📊 [ENROLLMENT] Extracted \(trimmed.count) valid frames (316 distances each)")
        return trimmed
    }

    /// Returns up to 10 frames, each with exactly 316 distances (indices 0...315)
    func VerifyFrameDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 10 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 10.")
            return []
        }

        let first10Frames = AllFramesOptionalAndMandatoryDistance.prefix(10)

        let trimmed = first10Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            // Take exactly 316 values: indices 0...315
            return Array(frame[0..<316])
        }

        print("📊 [VERIFICATION] Extracted \(trimmed.count) valid frames (316 distances each)")
        return trimmed
    }
}
