import SwiftUI

// MARK: - Mode of Collection
enum FrameCollectionMode: String, Codable {
    case registration
    case verification
}

// MARK: - Struct for distance + IOD
struct FrameDistance {
    let distances: [Float]
    let iod: Float
}

// MARK: - Calculating Distances for each frame
extension FaceManager {

    private var IOD_NORM_MAX: Float { 0.31 }

    // Function to remove extra digits after 4 digits after decimal
    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }

    // 1) Registration Mode: should we accept this frame?
    //    ✅ NO direction concept anymore
    private func shouldAcceptRegistrationFrame() -> Bool {
        switch registrationPhase {
        case .centerCollecting:
            // Phase 1 (centre tracking):
            // iodIsValid && iodNormalized<=0.31 && isHeadPoseStable && faceInsideOval
            return iodIsValid
            && iodNormalized <= IOD_NORM_MAX
            && isHeadPoseStable()
            && faceisInsideFaceOval

        case .movementCollecting:
            // Phase 2 (movement tracking):
            // isHeadPoseStable && faceInsideOval
            return isHeadPoseStable()
            && faceisInsideFaceOval

        case .done:
            return false
        }
    }

    // 2) Registration storage (no direction, just store by phase)
    private func storeRegistrationFrame(_ fd: FrameDistance) {
        switch registrationPhase {
        case .centerCollecting:
            centerFrames.append(fd)
            centerFramesCount = centerFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count

            // transition when 60 collected
            if centerFramesCount >= 60 {
                startMovementPhase(durationSec: 15)
            }

        case .movementCollecting:
            movementFrames.append(fd)
            movementFramesCount = movementFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count

        case .done:
            break
        }
    }

    // MARK: - Main distance compute + accept + store
    func calculateOptionalAndMandatoryDistances() {

        @inline(__always)
        func d(_ i: Int, _ j: Int, _ pts: [(x: Float, y: Float)]) -> Float {
            Helper.shared.calculateDistance(pts[i], pts[j])
        }

        guard !isBusy else { return }

        // Decide acceptance based on mode + registration phase
        let accept: Bool
        switch faceAuthManager.currentMode {
        case .registration:
            accept = shouldAcceptRegistrationFrame()

        case .verification:
            // Verification:
            // iodIsValid && iodNormalized<=0.31 && isHeadPoseStable && faceInsideOval
            accept = iodIsValid
            && iodNormalized <= IOD_NORM_MAX
            && isHeadPoseStable()
            && faceisInsideFaceOval
        }

        guard accept else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.rejectedFrames += 1
                
                // Debug logging for verification mode to understand rejections
                if self.faceAuthManager.currentMode == .verification {
                    #if DEBUG
                    print("❌ [Verification] Frame rejected (#\(self.rejectedFrames))")
                    print("   • IOD valid: \(self.iodIsValid)")
                    print("   • IOD normalized: \(String(format: "%.4f", self.iodNormalized)) (max: \(self.IOD_NORM_MAX))")
                    print("   • Head pose stable: \(self.isHeadPoseStable())")
                    print("   • Face in oval: \(self.faceisInsideFaceOval)")
                    print("   • Pitch: \(String(format: "%.2f", self.Pitch))")
                    print("   • Yaw: \(String(format: "%.2f", self.Yaw))")
                    print("   • Roll: \(String(format: "%.2f", self.Roll))")
                    #endif
                }
            }
            return
        }

        // Snapshot IOD for this accepted frame
        let iodAtCapture = iodNormalized

        let points = NormalizedPoints
        guard !points.isEmpty else { return }

        let mand = mandatoryLandmarkPoints.sorted()
        let opt  = selectedOptionalLandmarks

        var allDistances: [Float] = []
        allDistances.reserveCapacity(316)

        // mand-mand pairs
        for i in 0..<mand.count {
            let a = mand[i]
            for j in (i + 1)..<mand.count {
                allDistances.append(trunc4(d(a, mand[j], points)))
            }
        }

        // opt ring
        for i in 0..<opt.count {
            allDistances.append(trunc4(d(opt[i], opt[(i + 1) % opt.count], points)))
        }

        // mand-opt
        for a in mand {
            for b in opt {
                allDistances.append(trunc4(d(a, b, points)))
            }
        }

        guard allDistances.count == 316 else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.rejectedFrames += 1
                
                print("❌ [Frame Calculation] Invalid distance count!")
                print("   • Expected: 316 distances")
                print("   • Got: \(allDistances.count) distances")
                print("   • Mode: \(self.faceAuthManager.currentMode)")
            }
            return
        }

        let fd = FrameDistance(distances: allDistances, iod: iodAtCapture)
        let pb = latestPixelBuffer

        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isBusy else { return }

            switch self.faceAuthManager.currentMode {
            case .registration:
                self.storeRegistrationFrame(fd)

            case .verification:
                self.verificationFrameCollectedDistances.append(fd)
                let currentCount = self.verificationFrameCollectedDistances.count
                print("✅ [Verification] Frame accepted and stored!")
                print("   • Frame #\(currentCount)")
                print("   • Distances count: \(fd.distances.count)")
                print("   • IOD: \(String(format: "%.4f", fd.iod))")
                print("   • Progress: \(currentCount)/10 frames")
                
                self.totalFramesCollected = currentCount
                
                if currentCount >= 10 {
                    print("🎯 [Verification] Reached 10 frames milestone!")
                }
            }

            self.frameRecordedTrigger.toggle()

            if let pb {
                self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected, pixelBuffer: pb)
            }
        }
    }
}

// MARK: - Registration phase timers/state
extension FaceManager {

    func startMovementPhase(durationSec: Int) {
        let end = Date().addingTimeInterval(TimeInterval(durationSec))
        registrationPhase = .movementCollecting(endAt: end)
        movementSecondsRemaining = durationSec

        movementTimer?.cancel()
        movementTimer = nil

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: 0.2)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            guard case let .movementCollecting(endAt) = self.registrationPhase else { return }

            let rem = max(0, Int(ceil(endAt.timeIntervalSinceNow)))
            self.movementSecondsRemaining = rem

            if rem <= 0 {
                self.registrationPhase = .done
                self.registrationComplete = true
                self.movementTimer?.cancel()
                self.movementTimer = nil
            }
        }

        movementTimer = t
        t.resume()
    }

//    func resetRegistrationState() {
//        movementTimer?.cancel()
//        movementTimer = nil
//
//        registrationPhase = .centerCollecting
//        registrationComplete = false
//
//        centerFrames.removeAll()
//        movementFrames.removeAll()
//
//        centerFramesCount = 0
//        movementFramesCount = 0
//        movementSecondsRemaining = 0
//        totalFramesCollected = 0
//    }
}

// MARK: - Upload helpers
extension FaceManager {

    func registrationFramesForUpload() -> [FrameDistance] {
        (centerFrames + movementFrames).filter { $0.distances.count == 316 }
    }

    func verificationFrames10() -> [FrameDistance] {
        let allFrames = verificationFrameCollectedDistances
        
        print("📊 [verificationFrames10] Starting validation...")
        print("   • Total frames collected: \(allFrames.count)")
        
        // Filter for VALID frames only (must have exactly 316 distances)
        let validFrames = allFrames.filter { $0.distances.count == 316 }
        
        print("   • Valid frames (316 distances): \(validFrames.count)")
        print("   • Invalid frames: \(allFrames.count - validFrames.count)")
        
        guard validFrames.count >= 10 else {
            print("❌ [verificationFrames10] Not enough valid frames!")
            print("   • Need: 10 valid frames")
            print("   • Have: \(validFrames.count) valid frames")
            print("   • Total collected: \(allFrames.count) frames")
            return []
        }

        // Take the last 10 valid frames
        let selectedFrames = validFrames.suffix(10)
        print("   • Selected last 10 valid frames for verification")

        // Scale all distances by IOD
        let iodScaledFrames: [FrameDistance] = selectedFrames.map { frame in
            let scaledDistances = frame.distances.map { $0 / frame.iod }
            return FrameDistance(
                distances: scaledDistances,
                iod: frame.iod
            )
        }

        print("✅ [verificationFrames10] Verification frames prepared successfully")
        print("   • Frames ready: \(iodScaledFrames.count)")
        print("   • All frames IOD-scaled ✓")
        
        return iodScaledFrames
    }
    
    // MARK: - Verification Status Helper
    
    /// Returns the count of valid frames (exactly 316 distances) for verification
    func validVerificationFrameCount() -> Int {
        verificationFrameCollectedDistances.filter { $0.distances.count == 316 }.count
    }
    
    /// Check if verification has enough valid frames to proceed
    func isVerificationReady() -> Bool {
        validVerificationFrameCount() >= 10
    }
    
    /// Get detailed verification status for UI/debugging
    func verificationStatus() -> (total: Int, valid: Int, ready: Bool, message: String) {
        let total = verificationFrameCollectedDistances.count
        let valid = validVerificationFrameCount()
        let ready = valid >= 10
        
        let message: String
        if ready {
            message = "✅ Ready to verify (\(valid) valid frames)"
        } else {
            message = "⏳ Collecting frames... (\(valid)/10 valid)"
        }
        
        return (total, valid, ready, message)
    }
    
    /// Reset verification state (call this when starting new verification or on error)
    func resetVerificationState() {
        print("🔄 [Verification] Resetting verification state...")
        
        verificationFrameCollectedDistances.removeAll()
        totalFramesCollected = 0
        rejectedFrames = 0
        
        print("   • Cleared all verification frames")
        print("   • Reset counters to 0")
    }

}
