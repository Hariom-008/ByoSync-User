import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

struct FaceDetectionView: View {

    // Core managers
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager

    // NCNN liveness model
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()

    // Distance logging
    @State private var isDistanceLoggingStarted: Bool = false
    @State private var distanceLogFileURL: URL? = nil
    @State private var showDownloadButton: Bool = false
    @State private var showShareSheet = false

    // Auth token (for potential future use)
    let authToken: String
    let onComplete: () -> Void

    // EAR series
    @State private var earSeries: [CGFloat] = []
    private let earMaxSamples = 180
    private let blinkThreshold: CGFloat = 0.21

    // Pose buffers
    @State private var pitchSeries: [CGFloat] = []
    @State private var yawSeries:   [CGFloat] = []
    @State private var rollSeries:  [CGFloat] = []
    private let poseMaxSamples = 180

    // Animation state for frame recording indicator
    @State private var showRecordingFlash: Bool = false

    // UI State
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    // Show/hide normalized points overlay
    @State private var showNormalizedPoints: Bool = true

    // Target frame count for testing
    private let targetFrameCount = 100

    // MARK: - Init
    init(
        authToken: String,
        onComplete: @escaping () -> Void
    ) {
        self.authToken = authToken

        let camSpecManager = CameraSpecManager()
        _cameraSpecManager = StateObject(wrappedValue: camSpecManager)
        _faceManager = StateObject(wrappedValue: FaceManager(cameraSpecManager: camSpecManager))
        self.onComplete = onComplete
    }

    // MARK: - Derived UI state

    private var frameProgress: Double {
        Double(faceManager.totalFramesCollected) / Double(targetFrameCount)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                MediapipeCameraPreviewView(faceManager: faceManager)
                    .ignoresSafeArea()

                TargetFaceOvalOverlay(faceManager: faceManager)
                DirectionalGuidanceOverlay(faceManager: faceManager)
                NoseCenterCircleOverlay(isCentered: faceManager.isNoseTipCentered)

                if faceManager.isMovementTracking {
                    GazeVectorCard(
                        gazeVector: faceManager.GazeVector,
                        screenSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: faceManager.isMovementTracking)
                }

                VStack {
                    // Top status bar
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "cube.fill").foregroundColor(.purple)
                            Text("Distance Collection Mode")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)

                        Spacer()

                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("\(faceManager.totalFramesCollected) / \(targetFrameCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .monospacedDigit()
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 3)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(frameProgress >= 1.0 ? Color.green : Color.purple)
                                        .frame(width: geo.size.width * min(frameProgress, 1.0), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(faceManager.totalFramesCollected >= targetFrameCount ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    // Download/Share button
                    if showDownloadButton, let fileURL = distanceLogFileURL {
                        Button(action: {
                            print("📥 [Download] Preparing to share distance log file...")
                            Task { @MainActor in
                                await presentDistanceFile(fileURL)
                            }
                        }) {
                            VStack(spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                        .font(.system(size: 16))
                                    Text("Share Distance Log")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text("(\(faceManager.totalFramesCollected) frames collected)")
                                    .font(.system(size: 11, weight: .regular))
                                    .opacity(0.8)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green.opacity(0.9))
                            )
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .sheet(isPresented: $showShareSheet) {
                            if let fileURL = distanceLogFileURL {
                                ShareSheet(items: [fileURL])
                            }
                        }
                    }

                    // Collection complete indicator
                    if faceManager.totalFramesCollected >= targetFrameCount && !showDownloadButton {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Collection Complete!")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.2)))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }

                    Spacer()
                    
                    // Normalized Points Card at Bottom
                    if showNormalizedPoints {
                        VStack(spacing: 0) {
                            // Header with dismiss button
                            HStack {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                Text("Face Landmarks")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(faceManager.NormalizedPoints.count) points")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                // Dismiss button
                                Button(action: {
                                    print("🗑️ [NormalizedPoints] Dismissing overlay")
                                    withAnimation(.spring(duration: 0.3)) {
                                        showNormalizedPoints = false
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.leading, 8)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.purple.opacity(0.8))
                            
                            // Overlay visualization
                            NormalizedPointsOverlay(points: faceManager.NormalizedPoints)
                                .frame(width: 280, height: 280)
                                .background(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 0)
                                        .stroke(Color.purple.opacity(0.5), lineWidth: 2)
                                )
                        }
                        .background(Color.black)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: -5)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Show button to reveal overlay if dismissed
                    if !showNormalizedPoints {
                        Button(action: {
                            print("👁️ [NormalizedPoints] Showing overlay")
                            withAnimation(.spring(duration: 0.3)) {
                                showNormalizedPoints = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 12))
                                Text("Show Landmarks")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.8))
                            )
                        }
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .onChange(of: faceManager.EAR) { newEAR in
                var s = earSeries
                s.append(CGFloat(newEAR))
                if s.count > earMaxSamples { s.removeFirst(s.count - earMaxSamples) }
                earSeries = s
                print("👁️ [EAR] Updated: \(String(format: "%.3f", newEAR)) | Series count: \(earSeries.count)")
            }
            
            .onReceive(faceManager.$NormalizedPoints) { points in
                #if DEBUG
                print("📍 [NormalizedPoints] Updated: \(points.count) points")
                #endif
            }

            .onReceive(
                faceManager.$NormalizedPoints
                    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            ) { pts in
                if let (pitch, yaw, roll) = faceManager.computeAngles(from: pts) {
                    var p = pitchSeries; p.append(CGFloat(pitch))
                    var y = yawSeries;   y.append(CGFloat(yaw))
                    var r = rollSeries;  r.append(CGFloat(roll))

                    let cap = poseMaxSamples
                    if p.count > cap { p.removeFirst(p.count - cap) }
                    if y.count > cap { y.removeFirst(y.count - cap) }
                    if r.count > cap { r.removeFirst(r.count - cap) }

                    pitchSeries = p
                    yawSeries = y
                    rollSeries = r
                    
                    print("🎯 [HeadPose] Pitch: \(String(format: "%.1f°", pitch)) | Yaw: \(String(format: "%.1f°", yaw)) | Roll: \(String(format: "%.1f°", roll))")
                }
            }
            
            .onChange(of: faceManager.frameRecordedTrigger) { _ in
                showRecordingFlash = true
                print("📸 [Recording] Frame recorded! Total: \(faceManager.totalFramesCollected)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRecordingFlash = false
                }
            }

            .onAppear {
                print("🎬 [FaceDetectionView] View appeared - Distance Collection Mode")
            }

            // Distance logging logic
            .onChange(of: faceManager.totalFramesCollected) { oldValue, newValue in
                print("📊 [FrameCount] Current: \(newValue) | Target: \(targetFrameCount)")

                // Start logging on first frame
                if !isDistanceLoggingStarted && newValue > 0 {
                    print("📝 [DistanceLog] Starting distance logging...")
                    faceManager.startDistanceLogging()
                    isDistanceLoggingStarted = true
                }
                
                // Append the latest frame's distances
                if newValue > oldValue, newValue <= faceManager.AllFramesOptionalAndMandatoryDistance.count {
                    let frameIndex = newValue - 1
                    if let distances = faceManager.AllFramesOptionalAndMandatoryDistance[safe: frameIndex] {
                        faceManager.appendFrameDistances(frameIndex: frameIndex, distances: distances)
                        print("📝 [DistanceLog] Logged frame \(frameIndex) with \(distances.count) distances")
                    }
                }
                
                // Show download button when target frames collected
                if newValue >= targetFrameCount && !showDownloadButton {
                    print("✅ [DistanceLog] \(targetFrameCount) frames reached, enabling download...")
                    distanceLogFileURL = faceManager.getDistanceLogURL()
                    
                    // Verify file exists before showing button
                    if let fileURL = distanceLogFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                        withAnimation(.spring(duration: 0.5)) {
                            showDownloadButton = true
                        }
                        print("✅ [DistanceLog] File verified, button enabled")
                    } else {
                        print("⚠️ [DistanceLog] File not found, button not shown")
                    }
                }
            }

            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            ncnnViewModel.loadModels()
            ncnnViewModel.onLivenessUpdated = { [weak faceManager] score in
                faceManager?.updateFaceLivenessScore(score)
            }

            // Reset distance logging state
            isDistanceLoggingStarted = false
            showDownloadButton = false
            distanceLogFileURL = nil
            
            print("🎯 [FaceDetectionView] Ready to collect \(targetFrameCount) frames")
        }
        .onReceive(
            faceManager.$latestPixelBuffer
                .compactMap { $0 }
                .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
        ) { buffer in
            ncnnViewModel.processFrame(buffer)
        }
    }

    // MARK: - Download Distance File

    @MainActor
    private func presentDistanceFile(_ fileURL: URL) async {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ [Download] File doesn't exist at: \(fileURL.path)")
            alertTitle = "❌ File Not Found"
            alertMessage = "The distance log file could not be found. Please try collecting frames again."
            showAlert = true
            return
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("✅ [Download] File exists - Size: \(fileSize) bytes at: \(fileURL.path)")
            
            // Show share sheet
            showShareSheet = true
            
        } catch {
            print("❌ [Download] Failed to get file attributes: \(error.localizedDescription)")
            alertTitle = "❌ Download Failed"
            alertMessage = "Failed to access file: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Safe Array Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
