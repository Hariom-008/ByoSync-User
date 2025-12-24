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

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
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

    private var isBusy: Bool {
        isProcessing || faceIdFetchViewModel.isLoading || faceIdUploadViewModel.isUploading
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
        case .registration:
            return "Registration Mode"
        case .verification:
            return "Verification Mode"
        }
    }
    
    private var currentModeIcon: String {
        switch faceAuthManager.currentMode {
        case .registration:
            return "person.badge.plus.fill"
        case .verification:
            return "lock.shield.fill"
        }
    }
    
    private var currentModeColor: Color {
        switch faceAuthManager.currentMode {
        case .registration:
            return .green
        case .verification:
            return .blue
        }
    }
    
    // ✅ Target frame count based on mode
    private var targetFrameCount: Int {
        switch faceAuthManager.currentMode {
        case .registration:
            return 80
        case .verification:
            return 10
        }
    }
    
    // ✅ Progress percentage
    private var frameProgress: Double {
        Double(faceManager.totalFramesCollected) / Double(targetFrameCount)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            ZStack {
                // Camera preview
                MediapipeCameraPreviewView(faceManager: faceManager)
                    .ignoresSafeArea()

                TargetFaceOvalOverlay(faceManager: faceManager)

                DirectionalGuidanceOverlay(faceManager: faceManager)

                // Nose center overlay
                NoseCenterCircleOverlay(isCentered: faceManager.isNoseTipCentered)

                // Gaze vector (shown after calibration)
                if faceManager.isMovementTracking {
                    GazeVectorCard(
                        gazeVector: faceManager.GazeVector,
                        screenSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: faceManager.isMovementTracking)
                }

                // Busy overlay (processing + fetch + upload)
                if isBusy {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()

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
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                }

                VStack {
                    // ✅ Top status bar
                    HStack(spacing: 16) {
                        // Current mode indicator
                        HStack(spacing: 8) {
                            Image(systemName: currentModeIcon)
                                .foregroundColor(currentModeColor)
                            Text(currentModeText)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        
                        Spacer()

                        // Frame counter with progress
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                Text("\(faceManager.totalFramesCollected) / \(targetFrameCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .monospacedDigit()
                            }
                            
                            // Progress bar
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
                    
                    // ✅ Status message
                    if faceManager.totalFramesCollected >= targetFrameCount && !hasAutoTriggered {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text(faceAuthManager.currentMode == .registration ? "Processing registration..." : "Processing verification...")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // ✅ No buttons - automatic processing
                }
            }
            // EAR series update
            .onChange(of: faceManager.EAR) { newEAR in
                var s = earSeries
                s.append(CGFloat(newEAR))
                if s.count > earMaxSamples { s.removeFirst(s.count - earMaxSamples) }
                earSeries = s
            }
            // Nose center status update
            .onReceive(faceManager.$NormalizedPoints) { _ in
                faceManager.updateNoseTipCenterStatusFromCalcCoords()
            }
            // Pose buffers update (throttled)
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
                }
            }
            // Frame recorded indicator
            .onChange(of: faceManager.frameRecordedTrigger) { _ in
                showRecordingFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRecordingFlash = false
                }
            }
            // ✅ Auto-trigger based on frame count and mode
            .onChange(of: faceManager.totalFramesCollected) { oldValue, newValue in
                guard !hasAutoTriggered && !isBusy else { return }
                
                switch faceAuthManager.currentMode {
                case .registration:
                    if newValue >= 80 {
                        print("📸 [FaceDetectionView] 80 frames collected → Auto-triggering registration")
                        hasAutoTriggered = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            handleRegister()
                        }
                    }
                case .verification:
                    if newValue >= 10 {
                        print("🔐 [FaceDetectionView] 10 frames collected → Auto-triggering verification")
                        hasAutoTriggered = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            handleLogin()
                        }
                    }
                }
            }
            // (If FaceManager has its own upload flow)
            .onChange(of: faceManager.uploadSuccess) { success in
                if success {
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
            // ✅ UPDATED: Show upload success and navigate for registration
            .onChange(of: faceIdUploadViewModel.uploadSuccess) { ok in
                guard ok else { return }

                // Refresh backend data (new salt + faceData should be visible)
                faceIdFetchViewModel.fetchFaceIds()

                // Clear frames after successful upload
                faceManager.AllFramesOptionalAndMandatoryDistance = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

                // reset the VM flag
                faceIdUploadViewModel.resetState()
            }
            // Fetch errors
            .onChange(of: faceIdFetchViewModel.showError) { show in
                guard show else { return }
                alertTitle = "❌ Fetch Failed"
                alertMessage = faceIdFetchViewModel.errorMessage ?? "Unknown fetch error"
                showAlert = true
                hasAutoTriggered = false
            }
            // Upload errors
            .onChange(of: faceIdUploadViewModel.showError) { show in
                guard show else { return }
                alertTitle = "❌ Upload Failed"
                alertMessage = faceIdUploadViewModel.errorMessage ?? "Unknown upload error"
                showAlert = true
                hasAutoTriggered = false
            }
            // ✅ UPDATED: Alert handler with navigation logic
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    showAlert = false
                    
                    // ✅ Navigate on success (both registration and verification)
                    if alertTitle.contains("Successful") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            print("🎯 [FaceDetectionView] Success → calling onComplete() to navigate to MainTabView")
                            self.onComplete()
                        }
                    }
                    
                    // Reset on failure to allow retry
                    if alertTitle.contains("Failed") || alertTitle.contains("Error") {
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
            // Load models
            ncnnViewModel.loadModels()

            // Callback to update FaceManager liveness score
            ncnnViewModel.onLivenessUpdated = { [weak faceManager] score in
                faceManager?.updateFaceLivenessScore(score)
            }

            // Fetch enrollment status from backend for this device
            print("🌐 [FaceDetectionView] Fetching FaceIds on appear for deviceKey=\(DeviceIdentity.resolve())")
            print("🎯 [FaceDetectionView] Current mode: \(faceAuthManager.currentMode)")
            faceIdFetchViewModel.fetchFaceIds()
            
            // ✅ Reset trigger flag on appear
            hasAutoTriggered = false
        }
        // NCNN frames – throttled
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
        let count = faceIdFetchViewModel.faceIds.count
        let saltLen = faceIdFetchViewModel.faceIdData?.salt.count ?? 0
        print("📊 Enrollment status (backend): \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   Remote FaceId count: \(count)")
        print("   Remote salt len: \(saltLen)")
    }

    // MARK: - Register Handler

    private func handleRegister() {
        print("\n" + String(repeating: "=", count: 50))
        print("📸 AUTO-REGISTER TRIGGERED")
        print("Total frames collected: \(faceManager.totalFramesCollected)")
        print(String(repeating: "=", count: 50))

        isProcessing = true

        // Validate frames
        let allFrames = faceManager.save316LengthDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count

        print("📊 Frame Analysis (REGISTER):")
        print("   Total frames: \(allFrames.count)")
        print("   Valid frames (316 distances): \(validFrames.count)")
        print("   Invalid frames: \(invalidCount)")

        guard validFrames.count >= 80 else {
            print("❌ INSUFFICIENT VALID FRAMES FOR REGISTRATION")
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
                    print("✅ ========================================")
                    print("✅ REGISTRATION RECORDS GENERATED")
                    print("✅ Upload has been triggered via FaceIdViewModel")
                    print("✅ ========================================")
                    // Success alert will be shown on faceIdUploadViewModel.uploadSuccess

                case .failure(let error):
                    print("❌ ========================================")
                    print("❌ REGISTRATION GENERATION FAILED")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ ========================================")

                    self.alertTitle = "❌ Registration Failed"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLogin() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔐 AUTO-LOGIN TRIGGERED")
        print("Total frames collected: \(faceManager.totalFramesCollected)")
        print("Backend FaceId count in VM: \(faceIdFetchViewModel.faceIds.count)")
        print("backendEnrollmentValid: \(backendEnrollmentValid)")
        print(String(repeating: "=", count: 50))

        isProcessing = true

        guard backendEnrollmentValid else {
            print("❌ NO BACKEND ENROLLMENT DATA AVAILABLE FOR LOGIN (salt + faceData required)")
            isProcessing = false

            alertTitle = "❌ No Enrollment Found"
            alertMessage = "No usable face data found for this device on backend. Please register first."
            showAlert = true
            return
        }

        // ✅ FIX #1: Use VerifyFrameDistanceArray() for VERIFICATION mode
        let allFrames = faceManager.VerifyFrameDistanceArray()
        let validFrames = allFrames.filter { $0.count == 316 }
        let invalidCount = allFrames.count - validFrames.count

        print("📊 Frame Analysis (LOGIN):")
        print("   Total frames: \(allFrames.count)")
        print("   Valid frames (316 distances): \(validFrames.count)")
        print("   Invalid frames: \(invalidCount)")

        guard validFrames.count >= 10 else {
            print("❌ INSUFFICIENT VALID FRAMES FOR LOGIN")
            isProcessing = false

            alertTitle = "❌ Login Failed"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid\nInvalid: \(invalidCount)"
            showAlert = true
            return
        }

        print("🚀 Starting verification using loadAndVerifyFaceID wrapper...")

        // ✅ FIX #2: Use the wrapper method (like TestingLoginView)
        // This handles BOTH cache loading AND verification
        faceManager.loadAndVerifyFaceID(
            framesToVerify: validFrames,
            requiredMatches: 4,  // ✅ FIX #3: 4 out of 10 matches (40%)
            fetchViewModel: faceIdFetchViewModel
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false

                // Clear frames after verification
                self.faceManager.AllFramesOptionalAndMandatoryDistance = []
                self.faceManager.totalFramesCollected = 0
                self.hasAutoTriggered = false

                switch result {
                case .success(let verification):
                    let matchPercent = verification.matchPercentage

                    if verification.success {
                        print("✅ ========================================")
                        print("✅ LOGIN SUCCESSFUL! 🎉")
                        print("✅ Match: \(String(format: "%.1f", matchPercent))%")
                        print("✅ Notes: \(verification.notes)")
                        print("✅ ========================================")

                        self.alertTitle = "✅ Login Successful!"
                        self.alertMessage = "Welcome back!\n\nMatch: \(String(format: "%.1f", matchPercent))%"
                        self.showAlert = true
                        // ✅ onComplete() will be called when alert is dismissed

                    } else {
                        print("❌ ========================================")
                        print("❌ LOGIN FAILED ⛔")
                        print("❌ Match: \(String(format: "%.1f", matchPercent))%")
                        print("❌ Notes: \(verification.notes)")
                        print("❌ ========================================")

                        self.alertTitle = "❌ Login Failed"
                        self.alertMessage = "Face verification failed.\n\nMatch: \(String(format: "%.1f", matchPercent))%\n\n\(verification.notes)"
                        self.showAlert = true
                    }

                case .failure(let error):
                    print("❌ ========================================")
                    print("❌ VERIFICATION ERROR")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ ========================================")

                    self.alertTitle = "❌ Verification Error"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}
