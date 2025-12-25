import Foundation
import SwiftUI
import simd

extension FaceManager {

    @inline(__always)
    private func round4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return (x * factor).rounded() / factor
    }

    func calculateOptionalAndMandatoryDistances() {
        guard !NormalizedPoints.isEmpty else {
            print("⚠️ NormalizedPoints is empty, cannot compute pattern vector")
            return
        }

        var allDistances: [Float] = []

        let mand = mandatoryLandmarkPoints
        let opt  = selectedOptionalLandmarks

        // Validate indices
        let maxIdx = max(mand.max() ?? 0, opt.max() ?? 0)
        guard maxIdx < NormalizedPoints.count else {
            print("⚠️ Invalid landmark index \(maxIdx) for NormalizedPoints.count = \(NormalizedPoints.count)")
            return
        }

        @inline(__always)
        func d(_ i: Int, _ j: Int) -> Float {
            let p1 = NormalizedPoints[i]
            let p2 = NormalizedPoints[j]
            return Helper.shared.calculateDistance(p1, p2)
        }

        // ------------------------------------------------------------
        // 1) MANDATORY × MANDATORY  (NO SKIP)  => C(17,2) = 136
        // ------------------------------------------------------------
        let mandatoryStart = allDistances.count
        for i in 0..<mand.count {
            let idxA = mand[i]
            for j in (i + 1)..<mand.count {
                let idxB = mand[j]
                allDistances.append(round4(d(idxA, idxB)))
            }
        }
        let mandatoryCount = allDistances.count - mandatoryStart

        // ------------------------------------------------------------
        // 2) OPTIONAL CHAIN (ring) => opt.count = 10
        // ------------------------------------------------------------
        let optionalStart = allDistances.count
        for i in 0..<opt.count {
            let idxA = opt[i]
            let idxB = opt[(i + 1) % opt.count]
            allDistances.append(round4(d(idxA, idxB)))
        }
        let optionalChainCount = allDistances.count - optionalStart

        // ------------------------------------------------------------
        // 3) MANDATORY × OPTIONAL (aka OPTIONAL × MANDATORY)
        // ------------------------------------------------------------
        let bipartiteStart = allDistances.count
        for (a) in mand {
            for (b) in opt {
                allDistances.append(round4(d(a, b)))
            }
        }
        let bipartiteCount = allDistances.count - bipartiteStart

        // Debug
        print("""
        📏 Distances summary:
          mandatory×mandatory: \(mandatoryCount) (expected 136)
          optional chain:      \(optionalChainCount) (expected 10)
          mandatory×optional:  \(bipartiteCount) (expected \(mand.count * opt.count))
          TOTAL:               \(allDistances.count) (expected 316)
        """)

        // Store frame if gate passes (kept your logic)
        if iodIsValid && isNoseTipCentered && isHeadPoseStable() && !allDistances.isEmpty {
            AllFramesOptionalAndMandatoryDistance.append(allDistances)
            totalFramesCollected = AllFramesOptionalAndMandatoryDistance.count
            frameRecordedTrigger.toggle()

            enqueueAcceptedFrameUpload(frameIndex: totalFramesCollected)

            print("""
            ✅ FRAME ACCEPTED & STORED:
               frameIndex (1-based) = \(totalFramesCollected)
               vector length        = \(allDistances.count)
               total stored frames  = \(AllFramesOptionalAndMandatoryDistance.count)
            """)
        } else {
            rejectedFrames += 1
        }
    }
}
