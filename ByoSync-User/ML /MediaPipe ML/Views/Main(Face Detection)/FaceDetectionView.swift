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
    @State private var hideOverlays: Bool = false

    // UI State for enrollment/verification
    @State private var isEnrolled: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var isProcessing: Bool = false

    // ✅ Show/hide normalized points overlay
    @State private var showNormalizedPoints: Bool = true

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager

    // ✅ enrollment persistence gate
    @EnvironmentObject var enrollmentGate: EnrollmentGate

    // ✅ Auto-trigger tracking (prevent multiple triggers)
    @State private var hasAutoTriggered: Bool = false

    // Export state
    @State private var showExportSuccess: Bool = false
    @State private var exportedFileURL: URL?
    @State private var isExporting: Bool = false

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

    private var busyLocal: Bool {
        isProcessing || faceIdFetchViewModel.isLoading || faceIdUploadViewModel.isUploading
    }

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

    private var targetFrameCount: Int {
        switch faceAuthManager.currentMode {
        case .registration: return 60
        case .verification: return 10
        }
    }

    private var verificationTarget: Int { 10 }

    // ✅ NEW: Show VALID frame count for verification
    private var displayFrameCount: Int {
        switch faceAuthManager.currentMode {
        case .registration:
            return faceManager.totalFramesCollected
        case .verification:
            return faceManager.validVerificationFrameCount()
        }
    }

    private var topCounterText: String {
        switch faceAuthManager.currentMode {
        case .registration:
            switch faceManager.registrationPhase {
            case .centerCollecting:
                return "Center \(faceManager.centerFramesCount)/60"
            case .movementCollecting:
                return "Move \(faceManager.movementFramesCount) • \(faceManager.movementSecondsRemaining)s"
            case .done:
                return "Processing…"
            }
        case .verification:
            // ✅ Show VALID frames, not total
            return "\(faceManager.validVerificationFrameCount())/\(verificationTarget)"
        }
    }

    private var frameProgress: Double {
        switch faceAuthManager.currentMode {
        case .registration:
            switch faceManager.registrationPhase {
            case .centerCollecting:
                return Double(faceManager.centerFramesCount) / 60.0
            case .movementCollecting:
                let done = max(0, 15 - faceManager.movementSecondsRemaining)
                return Double(done) / 15.0
            case .done:
                return 1.0
            }
        case .verification:
            // ✅ Progress based on VALID frames
            return Double(faceManager.validVerificationFrameCount()) / Double(verificationTarget)
        }
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // ✅ Camera preview must ALWAYS stay mounted
                MediapipeCameraPreviewView(faceManager: faceManager)
                    .ignoresSafeArea()

                TargetFaceOvalOverlay(faceManager: faceManager)
                DirectionalGuidanceOverlay(faceManager: faceManager)

                // ✅ Single busy overlay (removed duplicate)
                if faceManager.isBusy {
                    ZStack {
                        Color.black.ignoresSafeArea()
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
                            Image(systemName: currentModeIcon)
                                .foregroundColor(currentModeColor)
                                .font(.system(size: 10, weight: .thin))
                            Text(currentModeText)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)

                        Spacer()

                        Button {
                            print("⏭️ [Skip] User tapped skip button")
                            DispatchQueue.main.async { onComplete() }
                        } label: {
                            Text("Skip")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(displayFrameCount >= targetFrameCount
                                      ? Color.green.opacity(0.8)
                                      : Color.black.opacity(0.7))
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)

                    if displayFrameCount >= targetFrameCount && !hasAutoTriggered {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(faceAuthManager.currentMode == .registration
                                 ? "Processing registration..."
                                 : "Processing verification...")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    }

                    Spacer()

                    // Export button at bottom
//                    if faceManager.totalFramesCollected > 0 {
//                        Button(action: exportFramesToCSV) {
//                            HStack(spacing: 8) {
//                                if isExporting {
//                                    ProgressView()
//                                        .scaleEffect(0.8)
//                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                } else {
//                                    Image(systemName: "arrow.down.doc.fill")
//                                        .font(.system(size: 14))
//                                }
//
//                                Text(isExporting ? "Exporting..." : "Export Frames to CSV")
//                                    .font(.system(size: 14, weight: .semibold))
//
//                                Text("(\(faceManager.totalFramesCollected))")
//                                    .font(.system(size: 12, weight: .medium))
//                                    .opacity(0.7)
//                            }
//                            .foregroundColor(.white)
//                            .padding(.horizontal, 20)
//                            .padding(.vertical, 12)
//                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.8)))
//                        }
//                        .disabled(isExporting)
//                        .padding(.bottom, 40)
//                        .transition(.move(edge: .bottom).combined(with: .opacity))
//                    }
                }
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
                }
            }

            // ✅ Keep FaceManager busy synced whenever drivers change
            .onAppear {
                syncBusy()
                print("🎬 [FaceDetectionView] View appeared")
            }
            .onChange(of: isProcessing) { _, _ in syncBusy() }
            .onChange(of: faceIdFetchViewModel.isLoading) { _, _ in syncBusy() }
            .onChange(of: faceIdUploadViewModel.isUploading) { _, _ in syncBusy() }

            // ✅ FIXED: Auto-trigger based on VALID frames for verification
            .onChange(of: faceManager.totalFramesCollected) { _, newValue in
                guard !hasAutoTriggered && !faceManager.isBusy else { return }

                if faceAuthManager.currentMode == .verification {
                    let validCount = faceManager.validVerificationFrameCount()
                    
                    print("📊 [Verification] Frame collected")
                    print("   • Total frames: \(newValue)")
                    print("   • Valid frames: \(validCount)")
                    
                    if validCount >= 10 {
                        print("✅ [Verification] Target reached: \(validCount) valid frames")
                        hasAutoTriggered = true
                        DispatchQueue.main.async { handleLogin() }
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

            // ✅ Upload success (registration)
            .onChange(of: faceIdUploadViewModel.uploadSuccess) { ok in
                guard ok else { return }

                print("✅ [Upload] Registration successful!")

                // ✅ NEW: Persist "hasFaceData" so we don't need status-fetch next time
                UserSession.shared.setHasFaceData(true)
                enrollmentGate.markEnrolled()

                faceManager.capturedFrames = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

                DispatchQueue.main.async { onComplete() }
                faceIdUploadViewModel.resetState()
            }

            .onChange(of: faceManager.registrationComplete) { _, done in
                guard done, !hasAutoTriggered, !faceManager.isBusy else { return }
                print("🎯 [Registration] Phase complete, triggering upload")
                hasAutoTriggered = true
                handleRegister()
            }

            .onChange(of: faceIdFetchViewModel.showError) { show in
                guard show else { return }
                alertTitle = "❌ Fetch Failed"
                alertMessage = faceIdFetchViewModel.errorMessage ?? "Unknown fetch error"
                showAlert = true
                hasAutoTriggered = false
            }

            .onChange(of: faceIdUploadViewModel.showError) { show in
                guard show else { return }
                alertTitle = "❌ Upload Failed"
                alertMessage = faceIdUploadViewModel.errorMessage ?? "Unknown upload error"
                showAlert = true
                hasAutoTriggered = false
            }

            // ✅ FIXED: Alert with proper reset action
//            .alert(alertTitle, isPresented: $showAlert) {
//                Button("OK") {
//                    print("🔄 [Alert] User tapped OK, resetting state...")
//                    
//                    // ✅ Reset verification state if in verification mode
//                    if faceAuthManager.currentMode == .verification {
//                        faceManager.resetVerificationState()
//                    }
//                    
//                    // ✅ Reset auto-trigger flag
//                    hasAutoTriggered = false
//                    
//                    // ✅ Dismiss alert
//                    showAlert = false
//                }
//            } message: {
//                Text(alertMessage)
//            }

            .alert("📥 Export Successful", isPresented: $showExportSuccess) {
                Button("OK") { showExportSuccess = false }
                if let url = exportedFileURL {
                    Button("Open in Files") { openFileInFilesApp(url: url) }
                    Button("Share") { shareCSVFile(url: url) }
                }
            } message: {
                if let url = exportedFileURL {
                    Text("CSV file saved to Documents:\n\n\(url.lastPathComponent)\n\nYou can find it in Files app under 'On My iPhone' > [Your App Name] > Documents")
                }
            }
        }
        .onAppear {
            // ✅ ensure session is running when view appears
            faceManager.startSessionIfNeeded()
            hasAutoTriggered = false
            syncBusy()

            print("🎯 [FaceDetectionView] Current mode: \(faceAuthManager.currentMode)")
            print("🌐 [FaceDetectionView] deviceKey=\(DeviceIdentity.resolve())")
            print("✅ [FaceDetectionView] UserSession.hasFaceData=\(UserSession.shared.hasFaceData)")

            // ✅ NEW: no "status fetch" on appear
            switch faceAuthManager.currentMode {
            case .registration:
                // You want the user to enroll now; don't waste network.
                enrollmentGate.markNotEnrolled()
                // no fetchFaceIds()
                break

            case .verification:
                if UserSession.shared.hasFaceData {
                    // Still need payload for verification, so fetch only in verification mode when boolean says it's present.
                    enrollmentGate.markEnrolled()
                    faceIdFetchViewModel.fetchFaceIds(hasFaceData: true)
                } else {
                    // no backend call; we already know there's no face data
                    enrollmentGate.markNotEnrolled()
                    alertTitle = "No usable face data"
                    alertMessage = "Please register first."
                    showAlert = true
                }
            }
        }
        .onDisappear {
            faceManager.stopSessionIfNeeded()
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
            // ✅ NEW: heal the cached boolean based on actual backend payload (only when we fetched)
            UserSession.shared.setHasFaceData(backendEnrollmentValid)
            backendEnrollmentValid ? enrollmentGate.markEnrolled() : enrollmentGate.markNotEnrolled()
        }

        let count = faceIdFetchViewModel.faceIds.count
        let saltLen = faceIdFetchViewModel.faceIdData?.salt.count ?? 0
        print("📊 Enrollment status (backend): \(isEnrolled ? "✅ Enrolled" : "❌ Not Enrolled")")
        print("   Remote FaceId count: \(count)")
        print("   Remote salt len: \(saltLen)")
    }

    // MARK: - Register Handler

    private func handleRegister() {
        print("📝 [Registration] Starting registration process...")
        isProcessing = true

        let frames = faceManager.registrationFramesForUpload()
        let valid = frames.filter { $0.distances.count == 316 }

        print("📝 [Registration] Frame validation:")
        print("   • Total frames: \(frames.count)")
        print("   • Valid frames: \(valid.count)")
        print("   • Invalid frames: \(frames.count - valid.count)")

        guard valid.count >= 60 else {
            isProcessing = false
            hasAutoTriggered = false
            
            alertTitle = "❌ Registration Failed"
            alertMessage = "Need at least 60 valid frames.\n\nFound: \(valid.count) valid\nTotal: \(frames.count) frames"
            showAlert = true
            
            print("❌ [Registration] Insufficient valid frames")
            return
        }

        print("✅ [Registration] Validation passed, starting upload...")

        faceManager.generateAndUploadFaceID(
            authToken: authToken,
            viewModel: faceIdUploadViewModel,
            frames: valid,
            minRequired: 60
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success:
                    DispatchQueue.main.async { self.onComplete() }
                    
                case .failure(let error):
                    print("❌ [Registration] Upload failed: \(error.localizedDescription)")
                    
                    self.alertTitle = "❌ Registration Failed"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true

                    // Reset state for retry
                    self.faceManager.capturedFrames = []
                    self.faceManager.totalFramesCollected = 0
                    self.hasAutoTriggered = false
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLogin() {
        print("🔐 [Verification] Starting verification process...")
        isProcessing = true

        // If we did not fetch (hasFaceData false), block immediately.
        guard UserSession.shared.hasFaceData else {
            enrollmentGate.markNotEnrolled()
            isProcessing = false
            hasAutoTriggered = false
            
            alertTitle = "❌ No Face Data"
            alertMessage = "You have no face data for this device. Please register first."
            showAlert = true
            
            print("❌ [Verification] No face data available")
            return
        }

        // If we fetched but payload invalid, also block.
        guard backendEnrollmentValid else {
            enrollmentGate.markNotEnrolled()
            isProcessing = false
            hasAutoTriggered = false
            
            alertTitle = "❌ Invalid Face Data"
            alertMessage = "Face data is not usable. Please register again."
            showAlert = true

            // heal cache
            UserSession.shared.setHasFaceData(false)
            
            print("❌ [Verification] Backend enrollment invalid")
            return
        }

        // ✅ FIXED: Let verificationFrames10() do ALL the validation
        let verificationFrames = faceManager.verificationFrames10()

        // If empty array returned, not enough valid frames
        guard !verificationFrames.isEmpty else {
            isProcessing = false
            hasAutoTriggered = false
            
            let validCount = faceManager.validVerificationFrameCount()
            let totalCount = faceManager.verificationFrameCollectedDistances.count
            
            alertTitle = "❌ Not Enough Valid Frames"
            alertMessage = "Need 10 valid frames for verification.\n\nValid: \(validCount)/10\nTotal collected: \(totalCount)"
            showAlert = true
            return
        }

        print("✅ [Verification] Frame validation passed")
        print("   • Valid frames ready: \(verificationFrames.count)")

        faceManager.loadAndVerifyFaceID(
            framesToVerify: verificationFrames,
            requiredMatches: 4,
            fetchViewModel: faceIdFetchViewModel, hasFaceData: UserSession.shared.hasFaceData
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false

                switch result {
                case .success(let verification):
                    let matchPercent = verification.matchPercentage

                    print("📊 [Verification] Result received")
                    print("   • Success: \(verification.success)")
                    print("   • Match: \(String(format: "%.1f", matchPercent))%")

                    if verification.success {
                        DispatchQueue.main.async { self.onComplete() }
                    } else {
                        // ✅ FIXED: Reset state for retry
                        self.faceManager.resetVerificationState()
                        self.hasAutoTriggered = false
                        
                        self.alertTitle = "❌ Verification Failed"
                        self.alertMessage = "Face verification failed."
                        self.showAlert = true
                        
                    }

                case .failure(let error):
                    // ✅ FIXED: Reset state for retry
                    self.faceManager.resetVerificationState()
                    self.hasAutoTriggered = false
                    
                    self.alertTitle = "⚠️ Verification Error"
                    self.alertMessage = "Error: \(error.localizedDescription)\n\nPlease try again."
                    self.showAlert = true
                    
                    print("❌ [Verification] Error occurred - state reset for retry")
                    print("   • Error: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Export to CSV

    private func exportFramesToCSV() {
        print("📥 [Export] Starting CSV export for mode: \(faceAuthManager.currentMode)")
        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let mode: FrameCollectionMode = (faceAuthManager.currentMode == .registration) ? .registration : .verification
                let url = try faceManager.exportCollectedFramesCSV(mode: mode)

                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportedFileURL = url
                    self.showExportSuccess = true
                    print("✅ [Export] CSV exported successfully to: \(url.path)")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.alertTitle = "❌ Export Failed"
                    self.alertMessage = "Failed to export frames: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    private func openFileInFilesApp(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success { self.shareCSVFile(url: url) }
            }
        } else {
            shareCSVFile(url: url)
        }
    }

    private func shareCSVFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        rootVC.present(activityVC, animated: true)
    }
}
