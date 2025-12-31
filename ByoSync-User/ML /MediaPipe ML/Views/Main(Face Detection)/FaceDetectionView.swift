import SwiftUI
internal import AVFoundation
import MediaPipeTasksVision
import Combine
import UIKit
import CoreImage

struct FaceDetectionView: View {

    // For saving frames of count 30 (for JPEG debug / liveness etc.)
    @State private var isSavingFrames: Bool = false
    @State private var savedFrameCount: Int = 0
    private let maxSavedFrames = 30

    // Core managers
    @StateObject private var faceManager: FaceManager
    @StateObject private var cameraSpecManager: CameraSpecManager

    // NCNN liveness model
    @StateObject private var ncnnViewModel = NcnnLivenessViewModel()

    // Backend FaceId VMs
    @StateObject private var faceIdUploadViewModel = FaceIdViewModel()
    @StateObject private var faceIdFetchViewModel = FaceIdFetchViewModel()

    // Auth / device identity (passed from parent)
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
    @State private var hideOverlays: Bool = false

    // UI State for enrollment/verification
    @State private var isEnrolled: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isProcessing: Bool = false

    // ✅ NEW: Show/hide normalized points overlay
    @State private var showNormalizedPoints: Bool = true

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager

    // ✅ NEW: enrollment persistence gate
    @EnvironmentObject var enrollmentGate: EnrollmentGate

    // ✅ Auto-trigger tracking (prevent multiple triggers)
    @State private var hasAutoTriggered: Bool = false

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

    /// Local busy computation (depends on view models + local state)
    private var busyLocal: Bool {
        isProcessing || faceIdFetchViewModel.isLoading || faceIdUploadViewModel.isUploading
    }

    /// Keep FaceManager's published busy in sync (so any child overlays can also observe it)
    private func syncBusy() {
        faceManager.setBusy(busyLocal)
    }

    /// Enrollment is "usable" only if backend returned BOTH salt + non-empty faceData.
    private var backendEnrollmentValid: Bool {
        guard faceIdFetchViewModel.hasLoadedOnce else { return false }
        guard let data = faceIdFetchViewModel.faceIdData else { return false }
        return !data.salt.isEmpty && !data.faceData.isEmpty
    }

    private var enrollmentStatusText: String {
        if !faceIdFetchViewModel.hasLoadedOnce { return "Checking…" }
        return backendEnrollmentValid ? "Enrolled" : "Not Enrolled"
    }

    private var enrollmentStatusIcon: String {
        if !faceIdFetchViewModel.hasLoadedOnce { return "hourglass.circle.fill" }
        return backendEnrollmentValid ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var enrollmentStatusColor: Color {
        if !faceIdFetchViewModel.hasLoadedOnce { return .yellow }
        return backendEnrollmentValid ? .green : .red
    }

    // ✅ Current mode display
    private var currentModeText: String {
        switch faceAuthManager.currentMode {
        case .registration: return "Registration Mode"
        case .verification: return "Verification Mode"
        }
    }

    private var currentModeIcon: String {
        switch faceAuthManager.currentMode {
        case .registration: return "person.badge.plus.fill"
        case .verification: return "lock.shield.fill"
        }
    }

    private var currentModeColor: Color {
        switch faceAuthManager.currentMode {
        case .registration: return .green
        case .verification: return .blue
        }
    }

    // ✅ Target frame count based on mode
    private var targetFrameCount: Int {
        switch faceAuthManager.currentMode {
        case .registration: return 80
        case .verification: return 20
        }
    }

    // ✅ Progress percentage
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

                
                // ✅ Busy overlay now driven by FaceManager
                if faceManager.isBusy {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text(faceIdUploadViewModel.isUploading ? "Uploading enrollment..."
                                 : (faceIdFetchViewModel.isLoading ? "Fetching enrollment..." : "Processing..."))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.8)))
                    }
                }

                VStack {
                    // Top status bar
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: currentModeIcon).foregroundColor(currentModeColor)
                                .font(.system(size: 8, weight: .thin))
                            Text(currentModeText)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
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
                                        .fill(frameProgress >= 1.0 ? Color.green : currentModeColor)
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

                    if faceManager.totalFramesCollected >= targetFrameCount && !hasAutoTriggered {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(faceAuthManager.currentMode == .registration ? "Processing registration..." : "Processing verification...")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }

                    Spacer()
                    
                    // ✅ Normalized Points Card at Bottom - Now with dismiss button and better visibility
//                    if showNormalizedPoints {
//                        VStack(spacing: 0) {
//                            // Header with dismiss button
//                            HStack {
//                                Image(systemName: "point.3.connected.trianglepath.dotted")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(.white)
//                                
//                                Text("Face Landmarks")
//                                    .font(.system(size: 12, weight: .semibold))
//                                    .foregroundColor(.white)
//                                
//                                Spacer()
//                                
//                                Text("\(faceManager.NormalizedPoints.count) points")
//                                    .font(.system(size: 10, weight: .medium))
//                                    .foregroundColor(.white.opacity(0.7))
//                                
//                                // Dismiss button
//                                Button(action: {
//                                    print("🗑️ [NormalizedPoints] Dismissing overlay")
//                                    withAnimation(.spring(duration: 0.3)) {
//                                        showNormalizedPoints = false
//                                    }
//                                }) {
//                                    Image(systemName: "xmark.circle.fill")
//                                        .font(.system(size: 18))
//                                        .foregroundColor(.white.opacity(0.8))
//                                }
//                                .padding(.leading, 8)
//                            }
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 10)
//                            .background(Color.blue.opacity(0.8))
//                            
//                            // Overlay visualization
//                            NormalizedPointsOverlay(points: faceManager.NormalizedPoints)
//                                .frame(width: 280, height: 280)
//                                .background(Color.black)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 0)
//                                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
//                                )
//                        }
//                        .background(Color.black)
//                        .cornerRadius(16)
//                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: -5)
//                        .padding(.horizontal, 24)
//                        .padding(.bottom, 40)
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                    }
//                    
                    // Show button to reveal overlay if dismissed
//                    if !showNormalizedPoints {
//                        Button(action: {
//                            print("👁️ [NormalizedPoints] Showing overlay")
//                            withAnimation(.spring(duration: 0.3)) {
//                                showNormalizedPoints = true
//                            }
//                        }) {
//                            HStack(spacing: 8) {
//                                Image(systemName: "point.3.connected.trianglepath.dotted")
//                                    .font(.system(size: 12))
//                                Text("Show Landmarks")
//                                    .font(.system(size: 12, weight: .semibold))
//                            }
//                            .foregroundColor(.white)
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 10)
//                            .background(
//                                RoundedRectangle(cornerRadius: 8)
//                                    .fill(Color.blue.opacity(0.8))
//                            )
//                        }
//                        .padding(.bottom, 40)
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                    }
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

            // ✅ Keep FaceManager busy synced whenever drivers change
            .onAppear {
                syncBusy()
                print("🎬 [FaceDetectionView] View appeared")
            }
            .onChange(of: isProcessing) { _, newValue in
                syncBusy()
                print("⚙️ [Processing] Status changed: \(newValue)")
            }
            .onChange(of: faceIdFetchViewModel.isLoading) { _, newValue in
                syncBusy()
                print("🔄 [Fetch] Loading status: \(newValue)")
            }
            .onChange(of: faceIdUploadViewModel.isUploading) { _, newValue in
                syncBusy()
                print("⬆️ [Upload] Status: \(newValue)")
            }

            // ✅ Auto-trigger based on frame count and mode
            .onChange(of: faceManager.totalFramesCollected) { _, newValue in
                guard !hasAutoTriggered && !faceManager.isBusy else { return }

                print("📊 [FrameCount] Current: \(newValue) | Target: \(targetFrameCount) | Mode: \(faceAuthManager.currentMode)")

                switch faceAuthManager.currentMode {
                case .registration:
                    if newValue >= 80 {
                        hasAutoTriggered = true
                        print("✅ [Registration] Auto-triggering registration...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            handleRegister()
                        }
                    }
                case .verification:
                    if newValue >= 10 {
                        hasAutoTriggered = true
                        print("✅ [Verification] Auto-triggering verification...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            handleLogin()
                        }
                    }
                }
            }

            .onChange(of: faceManager.uploadSuccess) { success in
                if success {
                    print("🎉 [Upload] Success! Completing flow...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        faceManager.resetForNewUser()
                        onComplete()
                    }
                }
            }

            // Keep isEnrolled in sync with backend payload (salt + list)
            .onChange(of: faceIdFetchViewModel.faceIdData) { _ in
                checkEnrollmentStatus()
            }
            .onChange(of: faceIdFetchViewModel.faceIds) { _ in
                checkEnrollmentStatus()
            }

            // ✅ Upload success
            .onChange(of: faceIdUploadViewModel.uploadSuccess) { ok in
                guard ok else { return }

                print("✅ [Upload] Registration successful!")
                enrollmentGate.markEnrolled()
                faceIdFetchViewModel.fetchFaceIds()

                faceManager.AllFramesOptionalAndMandatoryDistance = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

                faceIdUploadViewModel.resetState()
            }

            .onChange(of: faceIdFetchViewModel.showError) { show in
                guard show else { return }
                print("❌ [Fetch] Error: \(faceIdFetchViewModel.errorMessage ?? "Unknown")")
                alertTitle = "❌ Fetch Failed"
                alertMessage = faceIdFetchViewModel.errorMessage ?? "Unknown fetch error"
                showAlert = true
                hasAutoTriggered = false
            }

            .onChange(of: faceIdUploadViewModel.showError) { show in
                guard show else { return }
                print("❌ [Upload] Error: \(faceIdUploadViewModel.errorMessage ?? "Unknown")")
                alertTitle = "❌ Upload Failed"
                alertMessage = faceIdUploadViewModel.errorMessage ?? "Unknown upload error"
                showAlert = true
                hasAutoTriggered = false
            }

            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false

                    if alertTitle.contains("Successful") {
                        print("✅ [Alert] Success confirmed, completing flow...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.onComplete()
                        }
                    }

                    if alertTitle.contains("Failed") || alertTitle.contains("Error") {
                        print("🔄 [Alert] Error acknowledged, resetting frames...")
                        faceManager.AllFramesOptionalAndMandatoryDistance = []
                        faceManager.totalFramesCollected = 0
                        hasAutoTriggered = false
                    }
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

            print("🌐 [FaceDetectionView] Fetching FaceIds on appear for deviceKey=\(DeviceIdentity.resolve())")
            print("🎯 [FaceDetectionView] Current mode: \(faceAuthManager.currentMode)")

            if faceAuthManager.currentMode == .registration {
                enrollmentGate.markNotEnrolled()
            }

            faceIdFetchViewModel.fetchFaceIds()
            hasAutoTriggered = false

            // keep busy correct after starting fetch
            syncBusy()
        }
        .onReceive(
            faceManager.$latestPixelBuffer
                .compactMap { $0 }
                .throttle(for: .milliseconds(150), scheduler: RunLoop.main, latest: true)
        ) { buffer in
            ncnnViewModel.processFrame(buffer)
        }
    }

    // MARK: - Helper Functions

    private func checkEnrollmentStatus() {
        isEnrolled = backendEnrollmentValid

        if faceIdFetchViewModel.hasLoadedOnce {
            if backendEnrollmentValid {
                enrollmentGate.markEnrolled()
            } else {
                enrollmentGate.markNotEnrolled()
            }
        }

        let count = faceIdFetchViewModel.faceIds.count
        let saltLen = faceIdFetchViewModel.faceIdData?.salt.count ?? 0
        print("📊 Enrollment status (backend): \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   Remote FaceId count: \(count)")
        print("   Remote salt len: \(saltLen)")
    }

    // MARK: - Register Handler

    private func handleRegister() {
        print("🚀 [Register] Starting registration process...")
        isProcessing = true

        let allFrames = faceManager.save316LengthDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count

        print("📦 [Register] Total frames: \(allFrames.count) | Valid: \(validFrames.count) | Invalid: \(invalidCount)")

        guard validFrames.count >= 80 else {
            print("❌ [Register] Insufficient valid frames")
            isProcessing = false
            alertTitle = "❌ Registration Failed"
            alertMessage = "Need at least 80 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }

        faceManager.generateAndUploadFaceID(
            authToken: authToken,
            viewModel: faceIdUploadViewModel
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success:
                    print("✅ [Register] Face ID generated and uploaded successfully")
                case .failure(let error):
                    print("❌ [Register] Failed: \(error.localizedDescription)")
                    self.alertTitle = "❌ Registration Failed"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLogin() {
        print("🔐 [Login] Starting verification process...")
        isProcessing = true

        guard backendEnrollmentValid else {
            print("❌ [Login] No valid enrollment found")
            enrollmentGate.markNotEnrolled()

            isProcessing = false
            alertTitle = "❌ No Enrollment Found"
            alertMessage = "No usable face data found for this device on backend. Please register first."
            showAlert = true
            return
        }

        let allFrames = faceManager.VerifyFrameDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count

        print("📦 [Login] Total frames: \(allFrames.count) | Valid: \(validFrames.count) | Invalid: \(invalidCount)")

        guard validFrames.count >= 10 else {
            print("❌ [Login] Insufficient valid frames")
            isProcessing = false
            alertTitle = "❌ Login Failed"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }

        faceManager.loadAndVerifyFaceID(
            framesToVerify: validFrames,
            requiredMatches: 4,
            fetchViewModel: faceIdFetchViewModel
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false

                self.faceManager.AllFramesOptionalAndMandatoryDistance = []
                self.faceManager.totalFramesCollected = 0
                self.hasAutoTriggered = false

                switch result {
                case .success(let verification):
                    let matchPercent = verification.matchPercentage
                    print("📊 [Login] Verification result - Success: \(verification.success) | Match: \(String(format: "%.1f", matchPercent))%")
                    
                    if verification.success {
                        self.alertTitle = "✅ Login Successful!"
                        self.alertMessage = "Welcome back!\n\nMatch: \(String(format: "%.1f", matchPercent))%"
                        self.showAlert = true
                    } else {
                        self.alertTitle = "❌ Login Failed"
                        self.alertMessage = "Face verification failed.\n\nMatch: \(String(format: "%.1f", matchPercent))%\n\n\(verification.notes)"
                        self.showAlert = true
                    }
                case .failure(let error):
                    print("❌ [Login] Error: \(error.localizedDescription)")
                    self.alertTitle = "❌ Verification Error"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}
