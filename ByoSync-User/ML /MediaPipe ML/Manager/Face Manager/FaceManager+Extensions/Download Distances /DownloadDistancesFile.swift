import Foundation

extension FaceManager {

    // MARK: - Public API

    /// Exports collected frames (registration or verification) to a CSV that Excel can open.
    /// - Returns: URL of the saved CSV in Documents directory.
    func exportCollectedFramesCSV(mode: FrameCollectionMode) throws -> URL {
        let frames: [FrameDistance]
        switch mode {
        case .registration:
            frames = registrationFramesForUpload()          // raw (not IOD-divided)
        case .verification:
            frames = verificationFrameCollectedDistances    // raw (not IOD-divided)
        }

        guard let first = frames.first, first.distances.count == 316 else {
            throw ExportError.noFramesOrBadShape(found: frames.first?.distances.count ?? 0)
        }

        let headers = buildDistanceColumnHeaders() // 316 headers in exact compute order
        var csvLines: [String] = []

        // Build header row as a single CSV line (escape each cell)
        let headerCells = [csvEscape("IOD")] + headers.map { csvEscape($0) }
        csvLines.append(headerCells.joined(separator: ","))

        // Data rows
        for frame in frames {
            guard frame.distances.count == 316 else { continue }

            var row: [String] = []
            row.append(csvEscape(String(format: "%.6f", frame.iod)))

            for d in frame.distances {
                let before = d
                let after  = (frame.iod == 0) ? 0 : (d / frame.iod)

                // Cell must contain: "before, after" (quoted so CSV stays valid)
                let cell = String(format: "%.6f, %.6f", before, after)
                row.append(csvEscape(cell))
            }

            csvLines.append(row.joined(separator: ","))
        }

        let csv = csvLines.joined(separator: "\n")
        let filename = "Frames_\(mode.rawValue)_\(timestampString()).csv"

        let url = try saveToDocuments(filename: filename, contents: csv)
        #if DEBUG
        print("✅ CSV Exported: \(url)")
        #endif
        return url
    }

    // MARK: - Column headers in the SAME order as calculateOptionalAndMandatoryDistances()

    private func buildDistanceColumnHeaders() -> [String] {
        // Must match DistanceCalc+Size.swift order:
        // 1) mand-mand pairs (mand sorted)
        // 2) opt ring (selectedOptionalLandmarks order, ring)
        // 3) mand-opt pairs (mand sorted x opt order)

        let mand = mandatoryLandmarkPoints.sorted()
        let opt  = selectedOptionalLandmarks

        var headers: [String] = []
        headers.reserveCapacity(316)

        // 1) mand-mand pairs
        for i in 0..<mand.count {
            let a = mand[i]
            for j in (i + 1)..<mand.count {
                headers.append("[\(a)-\(mand[j])]")
            }
        }

        // 2) opt ring
        for i in 0..<opt.count {
            headers.append("[\(opt[i])-\(opt[(i + 1) % opt.count])]")
        }

        // 3) mand-opt
        for a in mand {
            for b in opt {
                headers.append("[\(a)-\(b)]")
            }
        }

        // Safety check
        #if DEBUG
        if headers.count != 316 {
            print("⚠️ Header count mismatch. Expected 316, got \(headers.count)")
        }
        #endif

        return headers
    }

    // MARK: - CSV + file helpers

    private func csvEscape(_ s: String) -> String {
        // Wrap in quotes; double any existing quotes
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func saveToDocuments(filename: String, contents: String) throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(filename)
        try contents.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private func timestampString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    enum ExportError: Error, LocalizedError {
        case noFramesOrBadShape(found: Int)

        var errorDescription: String? {
            switch self {
            case .noFramesOrBadShape(let found):
                return "No valid frames to export (distances count = \(found))."
            }
        }
    }
}
