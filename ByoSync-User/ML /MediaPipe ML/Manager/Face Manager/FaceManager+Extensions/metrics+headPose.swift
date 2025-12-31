import Foundation
import simd
import CoreGraphics

// MARK: - Face Metrics (EAR, Angles, Bounding Box)
extension FaceManager {
    
    // MARK: - Eye Aspect Ratio (EAR)
    /// Helper function to calculate distance between two SIMD2 points
    @inline(__always)
    private func dist(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        length(a - b)
    }
    
    /// Computes average Eye Aspect Ratio (EAR) from full 468-point mesh
    /// Lower EAR values indicate closed eyes, higher values indicate open eyes
    func earCalc(from landmarks: [SIMD2<Float>]) -> Float {
        guard landmarks.count > 387 else { return 0 }
        
        // LEFT eye: (160,144), (158,153) / (33,133)
        let A_left = dist(landmarks[160], landmarks[144])
        let B_left = dist(landmarks[158], landmarks[153])
        let C_left = dist(landmarks[33],  landmarks[133])
        guard C_left > 0 else { return 0 }
        let ear_left = (A_left + B_left) / (2.0 * C_left)
        
        // RIGHT eye: (385,380), (387,373) / (362,263)
        let A_right = dist(landmarks[385], landmarks[380])
        let B_right = dist(landmarks[387], landmarks[373])
        let C_right = dist(landmarks[362], landmarks[263])
        guard C_right > 0 else { return 0 }
        let ear_right = (A_right + B_right) / (2.0 * C_right)
        
        return (ear_left + ear_right) / 2.0
    }
    
    // MARK: - Head Pose Estimation (Pitch, Yaw, Roll)
    
    /// Calculates face orientation angles from nose tip and vertical line
    /// Assumes normalized coordinates (within unit circle)
    @inline(__always)
    func angleCalc(noseTip: (x: Float, y: Float),
                   verticalLine: (x: Float, y: Float)) -> (pitch: Float, yaw: Float, roll: Float) {
        
        let x = noseTip.x
        let y = noseTip.y
        
        // Calculate denominator for angle calculations
        let oneMinusR2 = max(0 as Float, 1 - (x * x + y * y))
        let den = sqrtf(oneMinusR2)
        
        // Use atan2 for stability
        let pitch = atan2f(y, den)
        let yaw   = atan2f(x, den)
        let roll  = atan2f(verticalLine.y, verticalLine.x)
        
        return (pitch, yaw, roll)
    }
    
    /// Computes angles from normalized landmarks (indices 4, 33, 263)
    func computeAngles(from landmarks: [(x: Float, y: Float)]) -> (pitch: Float, yaw: Float, roll: Float)? {
        let needed = [4, 33, 263]
        guard needed.allSatisfy({ $0 < landmarks.count }) else { return nil }
        
        let nose = landmarks[4]
        let p33 = landmarks[33]
        let p263 = landmarks[263]
        
        let v = (x: p33.x - p263.x, y: p33.y - p263.y)
        
        let oneMinusR2 = max(0 as Float, 1 - (nose.x * nose.x + nose.y * nose.y))
        let den = sqrtf(oneMinusR2)
        
        let pitch = atan2f(nose.y, den) 
        let yaw   = atan2f(nose.x, den)
        
        
        var roll = atan2f(v.y, v.x) // directed
        let halfPi: Float = .pi / 2
        if roll > halfPi { roll -= .pi }
        if roll < -halfPi { roll += .pi }
        
        if abs(roll) <= 0.05{
            
            let c = cosf(roll)
            let s = sinf(roll)
            
            @inline(__always)
            func rotateMinusRoll(_ pts: inout [(x: Float, y: Float)]) {
                // matrix: rotate by -roll around origin
                for i in pts.indices {
                    let x = pts[i].x
                    let y = pts[i].y
                    pts[i] = (x: x * c + y * s,
                              y: -x * s + y * c)
                }
            }
            
            @inline(__always)
            func rotatePlusRoll(_ pts: inout [(x: Float, y: Float)]) {
                // rotate by +roll around origin
                for i in pts.indices {
                    let x = pts[i].x
                    let y = pts[i].y
                    pts[i] = (x: x * c - y * s,
                              y: x * s + y * c)
                }
            }
            
            // If your coordinate conventions are consistent, this is enough:
            // rotateMinusRoll(&normalized)
            
            // If you want robustness across flips/mirroring, choose the one that makes the eye-line most horizontal (mod pi)
            var candA = landmarks
            var candB = landmarks
            rotateMinusRoll(&candA)
            rotatePlusRoll(&candB)
            
            func horizResidual(_ pts: [(x: Float, y: Float)]) -> Float {
                let a = pts[33], b = pts[263]
                let ang = atan2f(b.y - a.y, b.x - a.x)
                return abs(sinf(ang)) // 0 when angle is 0 or pi
            }
            
            self.NormalizedPoints = (horizResidual(candA) <= horizResidual(candB)) ? candA : candB
        }
        return (pitch, yaw, roll)
    }
    
    
    /// Checks if head pose is stable (within ±0.1 radians for all angles)
    func isHeadPoseStable() -> Bool {
        let threshold: Float = 0.1
        return abs(Pitch) <= threshold &&
        abs(Yaw) <= threshold &&
        abs(Roll) <= 0.05
    }
    
    
//    LEFT: yaw <= -0.30
//    RIGHT: yaw >= +0.30
//    UP: pitch <= -0.27
//    DOWN: pitch >= +0.27
//    CENTER-ish: abs(yaw) < 0.12 and abs(pitch) < 0.10 (optional tighter label)
}
