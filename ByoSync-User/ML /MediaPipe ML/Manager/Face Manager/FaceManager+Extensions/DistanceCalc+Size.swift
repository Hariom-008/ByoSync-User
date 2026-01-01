import SwiftUI

//MARK: Mode of Collection
enum FrameCollectionMode: String, Codable {
    case registration
    case verification
}
//MARK: Struct for distance+IOD
struct FrameDistance{
    let distances: [Float]
    let iod: Float
}

//MARK: Values to decide the head movement of User using Pitch and Yaw
private let LEFT_YAW:  Float = -0.30
private let RIGHT_YAW: Float =  0.30
private let UP_PITCH:  Float = -0.27
private let DOWN_PITCH:Float =  0.27
private let flipYaw = false   // set true if your device shows reversed sign
private let flipPitch = false // rarely needed
func classifyDirection(pitch: Float, yaw: Float) -> HeadDirection {
    let y = flipYaw ? -yaw : yaw
    let p = flipPitch ? -pitch : pitch
    
    if y <= LEFT_YAW  { return .left }
    if y >= RIGHT_YAW { return .right }
    if p <= UP_PITCH  { return .up }
    if p >= DOWN_PITCH{ return .down }
    return .center
}


//MARK: Calculating Distances for each frame
extension FaceManager {
    // Function to remove extra digits after 4 digits of after decimal
    @inline(__always)
    private func trunc4(_ x: Float) -> Float {
        let factor: Float = 10_000
        return Float(Int(x * factor)) / factor   // truncate toward 0
    }
    
    // 1. Registration Mode: To check whether to accept the frame or not
    private func shouldAcceptRegistrationFrame() -> (accept: Bool, direction: HeadDirection?) {
        guard iodIsValid else { return (false, nil) }
        
        switch registrationPhase {
        case .centerCollecting:
            // your new CENTER gate (no nose centered)
            let stable = isPoseStable(pitchThr: 0.10, yawThr: 0.10, rollThr: 0.05)
            
            return (stable && iodIsValid, .center)
            
        case .movementCollecting:
            // direction-based capture
            let dir = classifyDirection(pitch: Pitch, yaw: Yaw)
            guard dir != .center else { return (false, nil) } // ignore center in movement
            return (true, dir)
            
        case .done:
            return (false, nil)
        }
    }
    
    // 2. Registration storage
    private func storeRegistrationFrame(_ fd: FrameDistance, direction: HeadDirection?) {
        switch registrationPhase {
        case .centerCollecting:
            centerFrames.append(fd)
            centerFramesCount = centerFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count
            
            // ✅ transition immediately when 60 collected
            if centerFramesCount >= 60 {
                startMovementPhase(durationSec: 15)
            }
            
        case .movementCollecting:
            movementFrames.append(fd)
            movementFramesCount = movementFrames.count
            totalFramesCollected = centerFrames.count + movementFrames.count
            
            if let d = direction {
                capturedPerDir[d, default: 0] += 1
                // ✅ advance target only when user hit the current target
                if d == currentTarget {
                    currentTarget = nextTarget(after: d)
                }
            }
        case .done:
            break
        }
    }
    
    //MARK: Function for distances
    func calculateOptionalAndMandatoryDistances() {
        //Helper Function to find Distance between index in Normalized points array
        @inline(__always)
        func d(_ i: Int, _ j: Int) -> Float {
            Helper.shared.calculateDistance(points[i], points[j])
        }
        
        guard !isBusy else { return }
        
        //Decide acceptance based on mode + registration phase
        let acceptResult: (accept: Bool, direction: HeadDirection?)
        switch faceAuthManager.currentMode{
        case .registration:
            acceptResult = shouldAcceptRegistrationFrame()
        case .verification:
            let ok = iodIsValid && isNoseTipCentered && isPoseStable(pitchThr: 0.10, yawThr: 0.10, rollThr: 0.05)
            acceptResult = (ok, nil)
        }
        
        guard acceptResult.accept else {
            DispatchQueue.main.async { [weak self] in self?.rejectedFrames += 1 }
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
        
        // ✅ Store by phase + update UI counters
        let fd = FrameDistance(distances: allDistances, iod: iodAtCapture)
        let dir = acceptResult.direction
        let pb = latestPixelBuffer
        
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isBusy else { return }
            
            switch faceAuthManager.currentMode{
            case .registration:
                self.storeRegistrationFrame(fd, direction: dir)
                
            case .verification:
                self.verificationFrameCollectedDistances.append(fd)
                #if DEBUG
                print("Verification Mode Frame Collection : \(verificationFrameCollectedDistances.count)")
                #endif
                self.totalFramesCollected = self.verificationFrameCollectedDistances.count
            }
            
            self.frameRecordedTrigger.toggle()
            
            if let pb {
                self.enqueueAcceptedFrameUpload(frameIndex: self.totalFramesCollected, pixelBuffer: pb)
            }
        }
    }
}

extension FaceManager {
    
    func startMovementPhase(durationSec: Int) {
        let end = Date().addingTimeInterval(TimeInterval(durationSec))
        registrationPhase = .movementCollecting(endAt: end)
        movementSecondsRemaining = durationSec
        
        currentTarget = .left
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
    
    func resetRegistrationState() {
        movementTimer?.cancel()
        movementTimer = nil
        
        registrationPhase = .centerCollecting
        registrationComplete = false
        
        centerFrames.removeAll()
        movementFrames.removeAll()
        capturedPerDir = [.left:0,.right:0,.up:0,.down:0,.center:0]
        currentTarget = .left
        
        centerFramesCount = 0
        movementFramesCount = 0
        movementSecondsRemaining = 0
        totalFramesCollected = 0
    }
}

extension FaceManager {
    
    // Simple target cycle (you can replace with balancing logic)
    private func nextTarget(after d: HeadDirection) -> HeadDirection {
        switch d {
        case .left: return .right
        case .right: return .up
        case .up: return .down
        case .down: return .left
        case .center: return .left
        }
    }
}


//MARK: Checking the distance array size is exactly of size : 316
extension FaceManager{
    func registrationFramesForUpload() -> [FrameDistance] {
        return (centerFrames + movementFrames).filter { $0.distances.count == 316 }
    }
    
    func verificationFrames10() -> [[Float]] {
        let frames = verificationFrameCollectedDistances
        guard frames.count >= 10 else {
            #if DEBUG
            print("⚠️ Not enough valid frames. Have \(frames.count), need 10.")
            #endif
            return []
        }
        return frames.suffix(10).map { $0.distances }
    }
}
