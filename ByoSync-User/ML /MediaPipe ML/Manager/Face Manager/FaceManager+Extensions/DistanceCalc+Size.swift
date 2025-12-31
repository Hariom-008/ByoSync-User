import SwiftUI


struct FrameDistance{
    let distances: [Float]
    let iod: Float
}

//MARK: Calculating Distances for each frame
extension FaceManager {

    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }

    func calculateOptionalAndMandatoryDistances() {
        guard !isBusy else { return }

        // ✅ Gate FIRST
        guard iodIsValid,
              isNoseTipCentered,
              isHeadPoseStable()
        else {
            DispatchQueue.main.async { [weak self] in self?.rejectedFrames += 1 }
            return
        }

        // ✅ Snapshot iod for this accepted frame
        let iodAtCapture = iodNormalized  // or iodPixels (pick one consistently)

        // ✅ Snapshot points
        let points = NormalizedPoints
        guard !points.isEmpty else { return }

        let mand = mandatoryLandmarkPoints.sorted()
        let opt  = selectedOptionalLandmarks

        @inline(__always)
        func d(_ i: Int, _ j: Int) -> Float {
            Helper.shared.calculateDistance(points[i], points[j])
        }

        var allDistances: [Float] = []
        allDistances.reserveCapacity(316)

        for i in 0..<mand.count {
            let a = mand[i]
            for j in (i+1)..<mand.count {
                allDistances.append(trunc4(d(a, mand[j])))
            }
        }

        for i in 0..<opt.count {
            allDistances.append(trunc4(d(opt[i], opt[(i + 1) % opt.count])))
        }

        for a in mand {
            for b in opt {
                allDistances.append(trunc4(d(a, b)))
            }
        }

        guard allDistances.count == 316 else {
            DispatchQueue.main.async { [weak self] in self?.rejectedFrames += 1 }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isBusy else { return }
            self.capturedFrames.append(FrameDistance(distances: allDistances, iod: iodAtCapture))
            self.totalFramesCollected = self.capturedFrames.count
            self.frameRecordedTrigger.toggle()

            if let pb = self.latestPixelBuffer {
                self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected, pixelBuffer: pb)
            }
        }
    }

}



//MARK: Checking the distance array size is exactly of size : 316
extension FaceManager{

    private var validCapturedFrames: [FrameDistance] {
        capturedFrames.filter { $0.distances.count == 316 }
    }

    // Enrollment needs iod + distances
    func enrollmentFrames80() -> [FrameDistance] {
        let frames = validCapturedFrames
        guard frames.count >= 80 else {
            #if DEBUG
            print("⚠️ Not enough valid frames. Have \(frames.count), need 80.")
            #endif
            return []
        }
        return Array(frames.suffix(80))
    }
    
    func verificationFrames10() -> [[Float]] {
        let frames = validCapturedFrames
        guard frames.count >= 10 else {
            #if DEBUG
            print("⚠️ Not enough valid frames. Have \(frames.count), need 10.")
            #endif
            return []
        }
        return frames.suffix(10).map { $0.distances }
    }
}

