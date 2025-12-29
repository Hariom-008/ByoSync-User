import SwiftUI

extension FaceManager {

    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }

    func calculateOptionalAndMandatoryDistances() {
        // ✅ 1) Hard stop: don't even compute while busy
        guard !isBusy else { return }

        // ✅ 2) Snapshot points (avoid races)
        let points = NormalizedPoints
        guard !points.isEmpty else {
            #if DEBUG
            print("⚠️ NormalizedPoints is empty, cannot compute pattern vector")
            #endif
            return
        }

        let mand = mandatoryLandmarkPoints.sorted()
        var opt  = selectedOptionalLandmarks

        let maxIdx = max(mand.max() ?? 0, opt.max() ?? 0)
        guard maxIdx < points.count else {
            print("⚠️ Invalid landmark index \(maxIdx) for NormalizedPoints.count = \(points.count)")
            return
        }

        @inline(__always)
        func d(_ i: Int, _ j: Int) -> Float {
            let p1 = points[i]
            let p2 = points[j]
            return Helper.shared.calculateDistance(p1, p2)
        }

        var allDistances: [Float] = []
        allDistances.reserveCapacity(316)
        
        #if DEBUG
        var distanceOrder: [(String, Int, Int)] = []
        #endif

        // 1). mandatory×mandatory
        print("\n📏 === DISTANCE CALCULATION ORDER ===")
        print("🔵 MANDATORY × MANDATORY PAIRS:")
        for i in 0..<mand.count {
            let idxA = mand[i]
            for j in (i + 1)..<mand.count {
                let idxB = mand[j]
                let distance = trunc4(d(idxA, idxB))
                allDistances.append(distance)
                print("   [\(allDistances.count - 1)] mand[\(i)] × mand[\(j)] → landmark(\(idxA), \(idxB)) = \(distance)")
                #if DEBUG
                distanceOrder.append(("mand×mand", idxA, idxB))
                #endif
            }
        }

        // 2). optional chain
        print("\n🟢 OPTIONAL CHAIN (consecutive pairs):")
        for i in 0..<opt.count {
            let idxA = opt[i]
            let idxB = opt[(i + 1) % opt.count]
            let distance = trunc4(d(idxA, idxB))
            allDistances.append(distance)
            print("   [\(allDistances.count - 1)] opt[\(i)] → opt[\((i + 1) % opt.count)] → landmark(\(idxA), \(idxB)) = \(distance)")
            #if DEBUG
            distanceOrder.append(("opt→opt", idxA, idxB))
            #endif
        }

        // 3). mandatory×optional
        print("\n🟣 MANDATORY × OPTIONAL CROSS PAIRS:")
        opt = opt.sorted()
        for a in mand {
            for b in opt {
                let distance = trunc4(d(a, b))
                allDistances.append(distance)
                print("   [\(allDistances.count - 1)] mand × opt → landmark(\(a), \(b)) = \(distance)")
                #if DEBUG
                distanceOrder.append(("mand×opt", a, b))
                #endif
            }
        }
        
        print("\n📊 SUMMARY:")
        print("   Total distances calculated: \(allDistances.count)")
        print("   Mandatory landmarks: \(mand)")
        print("   Optional landmarks: \(opt)")
        print("=================================\n")

        //Gate right before storing
        guard iodIsValid,
              isNoseTipCentered,
              isHeadPoseStable(),
              !allDistances.isEmpty,
              !isBusy
        else {
            DispatchQueue.main.async { [weak self] in
                self?.rejectedFrames += 1
            }
            return
        }

        // Publish state on main
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.isBusy else { return }

            self.AllFramesOptionalAndMandatoryDistance.append(allDistances)
            self.totalFramesCollected = self.AllFramesOptionalAndMandatoryDistance.count
            self.frameRecordedTrigger.toggle()
            
            self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected, pixelBuffer: latestPixelBuffer!)
            #if DEBUG
            print("""
            ✅ FRAME ACCEPTED & STORED:
               frameIndex (1-based) = \(totalFramesCollected)
               vector length        = \(allDistances.count)
               total stored frames  = \(AllFramesOptionalAndMandatoryDistance.count)
            """)
            #endif
        }
    }
}
