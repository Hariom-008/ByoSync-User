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

    // ✅ NEW: Show/hide normalized points overlay
    @State private var showNormalizedPoints: Bool = true

    // ✅ Face auth mode manager
    @EnvironmentObject var faceAuthManager: FaceAuthManager

    // ✅ NEW: enrollment persistence gate
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
        case .registration: return 60
        case .verification: return 10
        }
    }
    private var registrationTopText: String {
        // You'll expose these from FaceManager (see overlay section)
        switch faceManager.registrationPhase {
        case .centerCollecting:
            return "Center \(faceManager.centerFrames) / 60"
        case .movementCollecting:
            return "Move \(faceManager.movementFrames) • \(faceManager.movementSecondsRemaining)s"
        case .done:
            return "Processing…"
        }
    }

    private var verificationTarget: Int { 10 }

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
            return "\(faceManager.totalFramesCollected)/\(verificationTarget)"
        }
    }

    private var frameProgress: Double {
        switch faceAuthManager.currentMode {
        case .registration:
            switch faceManager.registrationPhase {
            case .centerCollecting:
                return Double(faceManager.centerFramesCount) / 60.0
            case .movementCollecting:
                // progress by time remaining
                let done = max(0, 15 - faceManager.movementSecondsRemaining)
                return Double(done) / 15.0
            case .done:
                return 1.0
            }
        case .verification:
            return Double(faceManager.totalFramesCollected) / Double(verificationTarget)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera preview
                if !faceManager.isBusy{
                    MediapipeCameraPreviewView(faceManager: faceManager)
                        .ignoresSafeArea()
                    
                    TargetFaceOvalOverlay(faceManager: faceManager)
                    DirectionalGuidanceOverlay(faceManager: faceManager)
                }
                
                if faceManager.isBusy{
                    Color.black
                        .ignoresSafeArea()
                }
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
                                .font(.system(size: 10, weight: .thin))
                            Text(currentModeText)
                                .font(.system(size: 12, weight: .semibold))
                            
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)

                        Spacer()

                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Button{
                                    print("⏭️ [Skip] User tapped skip button")
                                    DispatchQueue.main.async{
                                      onComplete()
                                    }
                                }label:{
                                    Text("Skip")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16,weight:.semibold,design:.rounded))
                                }
                            }
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
                    
                    // Export button at bottom
                    if faceManager.totalFramesCollected > 0 {
                        Button(action: exportFramesToCSV) {
                            HStack(spacing: 8) {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 14))
                                }
                                
                                Text(isExporting ? "Exporting..." : "Export Frames to CSV")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("(\(faceManager.totalFramesCollected))")
                                    .font(.system(size: 12, weight: .medium))
                                    .opacity(0.7)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.8))
                            )
                        }
                        .disabled(isExporting)
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

            .onChange(of: faceManager.totalFramesCollected) { _, newValue in
                guard !hasAutoTriggered && !faceManager.isBusy else { return }

                if faceAuthManager.currentMode == .verification, newValue >= 10 {
                    print("✅ [Verification] Target reached: \(newValue) frames")
                    hasAutoTriggered = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { handleLogin() }
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
               // faceIdFetchViewModel.fetchFaceIds()

                faceManager.capturedFrames = []
                faceManager.totalFramesCollected = 0
                hasAutoTriggered = false

                alertTitle = "✅ Registration Successful"
                alertMessage = "Your face has been enrolled successfully!"
                showAlert = true

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

//            .alert(alertTitle, isPresented: $showAlert) {
//                Button("OK") {
//                    showAlert = false
//
//                    if alertTitle.contains("Successful") {
//                        print("✅ [Alert] Success confirmed, completing flow...")
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                            self.onComplete()
//                        }
//                    }
//
//                    if alertTitle.contains("Failed") || alertTitle.contains("Error") {
//                        print("🔄 [Alert] Error acknowledged, resetting frames...")
//                        faceManager.capturedFrames = []
//                        faceManager.totalFramesCollected = 0
//                        hasAutoTriggered = false
//                    }
//                }
//            } message: {
//                Text(alertMessage)
//            }
            
            // Export success alert
            .alert("📥 Export Successful", isPresented: $showExportSuccess) {
                Button("OK") {
                    showExportSuccess = false
                }
                if let url = exportedFileURL {
                    Button("Open in Files") {
                        openFileInFilesApp(url: url)
                    }
                    Button("Share") {
                        shareCSVFile(url: url)
                    }
                }
            } message: {
                if let url = exportedFileURL {
                    Text("CSV file saved to Documents:\n\n\(url.lastPathComponent)\n\nYou can find it in the Files app under 'On My iPhone' > [Your App Name] > Documents")
                }
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
        isProcessing = true

        // ✅ you define this helper in FaceManager (see next section)
        let frames = faceManager.registrationFramesForUpload()
        let valid = frames.filter { $0.distances.count == 316 }

        print("📝 [Registration] Total frames: \(frames.count), Valid: \(valid.count)")

        guard valid.count >= 60 else {
            isProcessing = false
            alertTitle = "❌ Registration Failed"
            alertMessage = "Need at least 60 valid frames.\n\nFound: \(valid.count) valid"
            showAlert = true
            return
        }

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
                    print("✅ [Registration] Upload successful")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onComplete()
                    }
                case .failure(let error):
                    print("❌ [Registration] Upload failed: \(error.localizedDescription)")
                    self.alertTitle = "❌ Registration Failed"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                    
                    faceManager.capturedFrames = []
                    faceManager.totalFramesCollected = 0
                    hasAutoTriggered = false
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLogin() {
        isProcessing = true

        guard backendEnrollmentValid else {
            enrollmentGate.markNotEnrolled()

            isProcessing = false
            alertTitle = "No usable face data"
            alertMessage = "You have no usable face data for this device please register first."
            showAlert = true
            return
        }

        let allFrames = faceManager.verificationFrames10()
        let validFrames = allFrames.filter { $0.distances.count == 316 }
    
        print("🔐 [Verification] Total frames: \(allFrames.count), Valid: \(validFrames.count)")

        guard validFrames.count >= 10 else {
            print("❌ [Login] Insufficient valid frames")
            isProcessing = false
            alertTitle = "Failed to Login"
            alertMessage = "Need at least 10 valid frames.\n\nFound: \(validFrames.count) valid"
            showAlert = true
            return
        }

        faceManager.loadAndVerifyFaceID(
            framesToVerify: allFrames,
            requiredMatches: 4,
            fetchViewModel: faceIdFetchViewModel
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false

                self.faceManager.capturedFrames = []
                self.faceManager.totalFramesCollected = 0
                self.hasAutoTriggered = false

                switch result {
                case .success(let verification):
                    let matchPercent = verification.matchPercentage
                    print("📊 [Login] Verification result - Success: \(verification.success) | Match: \(String(format: "%.1f", matchPercent))%")
                    
                    if verification.success {
                        self.alertTitle = "👋 Login Successful"
                        self.alertMessage = "Press this button to close the alert"
                        self.showAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.onComplete()
                        }
                    } else {
                        self.alertTitle = "Failed to Login"
                        self.alertMessage = "Face verification failed. Try again"
                        self.showAlert = true
                        
                        faceManager.capturedFrames = []
                        faceManager.totalFramesCollected = 0
                        hasAutoTriggered = false
                        
                        print("Face verification failed.\n\nMatch: \(String(format: "%.1f", matchPercent))%\n\n\(String(describing: verification.notes))")
                    }
                case .failure(let error):
                    print("⚠️ [Verification] Error: \(error.localizedDescription)")
                    self.alertTitle = "⚠️Verification Error"
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
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
                    print("❌ [Export] Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    
    private func openFileInFilesApp(url: URL) {
        print("📂 [Files] Attempting to open file: \(url.lastPathComponent)")
        
        // Try to open with the system's default handler
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("✅ [Files] File opened successfully")
                } else {
                    print("⚠️ [Files] Failed to open file, falling back to share")
                    self.shareCSVFile(url: url)
                }
            }
        } else {
            print("⚠️ [Files] Cannot open URL, using share instead")
            shareCSVFile(url: url)
        }
    }
    
    private func shareCSVFile(url: URL) {
        print("📤 [Share] Presenting share sheet for: \(url.lastPathComponent)")
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            print("❌ [Share] Failed to find window scene or root view controller")
            return
        }
        
        // iPad requires popover configuration
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
            print("📱 [Share] Configured for iPad popover presentation")
        }
        
        rootVC.present(activityVC, animated: true) {
            print("✅ [Share] Activity controller presented successfully")
        }
    }
}
