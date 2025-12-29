import Foundation

extension FaceManager {
    
    // MARK: - Distance File Logging
    
    private static var distanceFileURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("frame_distances.txt")
    }
    
    /// Start a fresh distance log file (clears any existing file)
    func startDistanceLogging() {
        guard let fileURL = Self.distanceFileURL else {
            print("❌ [DistanceLog] Failed to get file URL")
            return
        }
        
        // Create header
        let header = """
        Frame Distance Log
        Generated: \(Date())
        Format: Frame index followed by 316 distances per line
        ==========================================
        
        """
        
        do {
            try header.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ [DistanceLog] Started new log file at: \(fileURL.path)")
        } catch {
            print("❌ [DistanceLog] Failed to create file: \(error.localizedDescription)")
        }
    }
    
    /// Append a single frame's distances to the log file
    func appendFrameDistances(frameIndex: Int, distances: [Float]) {
        guard let fileURL = Self.distanceFileURL else {
            print("❌ [DistanceLog] Failed to get file URL")
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [DistanceLog] File doesn't exist, creating it...")
            startDistanceLogging()
            return appendFrameDistances(frameIndex: frameIndex, distances: distances)
        }
        
        // Format: "Frame X: dist1, dist2, dist3, ...\n"
        let distanceString = distances.map { String(format: "%.6f", $0) }.joined(separator: ", ")
        let line = "Frame \(frameIndex): \(distanceString)\n"
        
        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle.seekToEndOfFile()
            if let data = line.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
            print("📝 [DistanceLog] Appended frame \(frameIndex) with \(distances.count) distances")
        } catch {
            print("❌ [DistanceLog] Failed to append: \(error.localizedDescription)")
        }
    }
    
    /// Get the current distance log file URL for sharing
    func getDistanceLogURL() -> URL? {
        guard let fileURL = Self.distanceFileURL else {
            print("❌ [DistanceLog] Failed to get file URL")
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ [DistanceLog] File doesn't exist yet")
            return nil
        }
        
        print("📂 [DistanceLog] File available at: \(fileURL.path)")
        return fileURL
    }
    
    /// Clear the distance log file
    func clearDistanceLog() {
        guard let fileURL = Self.distanceFileURL else { return }
        
        try? FileManager.default.removeItem(at: fileURL)
        print("🗑️ [DistanceLog] Cleared log file")
    }
    
    // MARK: - Frame Processing
    
    /// Returns last 80 frames, each with exactly 316 distances
    func save316LengthDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 80 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 80.")
            return []
        }

        let last80Frames = AllFramesOptionalAndMandatoryDistance.suffix(80)

        let trimmed = last80Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            return Array(frame[0..<316])
        }
        return trimmed
    }

    /// Returns last 10 frames, each with exactly 316 distances
    func VerifyFrameDistanceArray() -> [[Float]] {
        guard AllFramesOptionalAndMandatoryDistance.count >= 10 else {
            print("⚠️ Not enough frames. Have \(AllFramesOptionalAndMandatoryDistance.count), need at least 10.")
            return []
        }

        let last10Frames = AllFramesOptionalAndMandatoryDistance.suffix(10)

        let trimmed = last10Frames.compactMap { frame -> [Float]? in
            guard frame.count >= 316 else {
                print("⚠️ Frame too short: \(frame.count), need at least 316")
                return nil
            }
            return Array(frame[0..<316])
        }

        print("📊 [VERIFICATION] Extracted \(trimmed.count) valid frames (316 distances each)")
        return trimmed
    }
}
