import SwiftUI
import AVFoundation
import MediaPipeTasksVision

struct FaceDetectionView: View {
    @StateObject private var cameraManager = CameraManager()
    
    // Receive phone number from ContentView
    let phoneNumber: String
    let onComplete: () -> Void  // Callback when upload is complete

    @State private var earSeries: [CGFloat] = []
    private let earMaxSamples = 180
    private let earRange: ClosedRange<CGFloat> = 0.0...0.5
    private let blinkThreshold: CGFloat = 0.21

    // Pose buffers
    @State private var pitchSeries: [CGFloat] = []
    @State private var yawSeries:   [CGFloat] = []
    @State private var rollSeries:  [CGFloat] = []
    private let poseMaxSamples = 180
    private let poseRange: ClosedRange<CGFloat> = (-.pi)...(.pi)

    // Animation state for frame recording indicator
    @State private var showRecordingFlash: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let isCompact = screenWidth < 1024 || screenHeight < 768
            
            ZStack {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()

                // 👁️ Gaze vector overlay (visible after Stop)
                if cameraManager.isMovementTracking {
                    GazeVectorCard(
                        gazeVector: cameraManager.GazeVector,
                        screenSize: geometry.size
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: cameraManager.isMovementTracking)
                }

                // 📱 Phone Number Display (top center)
                VStack {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.cyan)
                            
                            Text(phoneNumber)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.cyan.opacity(0.3),
                                            Color.blue.opacity(0.3)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 10)
                        .padding(.top, 16)
                        
                        Spacer()
                    }
                    Spacer()
                }

                // 📊 Frame Recording Indicator (top right)
                VStack {
                    HStack {
                        Spacer()
                        
                        if cameraManager.totalFramesCollected > 0 {
                            HStack(spacing: 8) {
                                // Pulsing circle when recording
                                Circle()
                                    .fill(showRecordingFlash ? Color.green : Color.green.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(showRecordingFlash ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: showRecordingFlash)
                                
                                Text("Frames: \(cameraManager.totalFramesCollected)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.6))
                            )
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                        }
                    }
                    Spacer()
                }
                
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()
                    
                    // Head pose stability indicator
                    HStack(spacing: 8) {
                        if cameraManager.isHeadPoseStable() {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("Head Stable")
                                .font(.caption)
                                .foregroundColor(.white)
                        } else {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text("Stabilizing...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.black.opacity(0.6))
                    )
                    
                    Spacer()
            
                    HStack(spacing: isCompact ? 12 : 20) {
                        Spacer()
                        
                        if cameraManager.isCentreTracking {
                            // Show Stop button when centre tracking is active
                            Button {
                                cameraManager.isCentreTracking = false
                                cameraManager.isMovementTracking = true
                                cameraManager.calculateCenterMeans()
                                print("🟣 Center tracking stopped — using calibrated means")
                            } label: {
                                Text("Stop")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                    .padding(.horizontal, isCompact ? 16 : 24)
                                    .padding(.vertical, isCompact ? 10 : 12)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(isCompact ? 8 : 10)
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Show Start button when centre tracking is not active
                            Button {
                                cameraManager.isCentreTracking = true
                                cameraManager.isMovementTracking = false
                                cameraManager.actualLeftList.removeAll()
                                cameraManager.actualRightList.removeAll()
                                cameraManager.landmarkDistanceLists.removeAll()
                                cameraManager.totalFramesCollected = 0
                                print("🟢 Center tracking started — collecting neutral points")
                            } label: {
                                Text("Start")
                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                    .padding(.horizontal, isCompact ? 16 : 24)
                                    .padding(.vertical, isCompact ? 10 : 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(isCompact ? 8 : 10)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // 📊 Print Data Button
                        Button {
                            cameraManager.printAllLandmarkDistances()
                        } label: {
                            Text("Print")
                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                .padding(.horizontal, isCompact ? 16 : 24)
                                .padding(.vertical, isCompact ? 10 : 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(isCompact ? 8 : 10)
                        }
                        
                        // 🚀 Upload Button
                        Button {
                            Task {
                                await cameraManager.uploadFacePattern()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if cameraManager.isUploadingPattern {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else if cameraManager.uploadSuccess {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .foregroundColor(.white)
                                }
                                Text(cameraManager.isUploadingPattern ? "Uploading..." : "Upload")
                            }
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .padding(.horizontal, isCompact ? 16 : 24)
                            .padding(.vertical, isCompact ? 10 : 12)
                            .background(
                                cameraManager.uploadSuccess ? Color.green :
                                cameraManager.isUploadingPattern ? Color.orange : Color.purple
                            )
                            .foregroundColor(.white)
                            .cornerRadius(isCompact ? 8 : 10)
                        }
                        .disabled(cameraManager.isUploadingPattern || cameraManager.landmarkDistanceLists.isEmpty)
                        .opacity(cameraManager.landmarkDistanceLists.isEmpty ? 0.5 : 1.0)
                        
                        Spacer()
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .animation(.easeInOut(duration: 0.2), value: cameraManager.isCentreTracking)
                    
                    Spacer()
                        .frame(maxHeight: isCompact ? 16 : 24)
                    
                    // Overlays Section
                    if isCompact {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                overlayCards(
                                    screenWidth: screenWidth,
                                    screenHeight: screenHeight,
                                    isCompact: true
                                )
                            }
                           .padding(.leading, 20)
                        }
                        .frame(height: min(screenHeight * 0.3, 200))
                    } else {
                        HStack(spacing: 16) {
                            Spacer()
                            overlayCards(
                                screenWidth: screenWidth,
                                screenHeight: screenHeight,
                                isCompact: false
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                        .frame(height: isCompact ? 12 : 24)
                }
            }
            .onAppear {
                // Set phone number when view appears
                cameraManager.FaceOwnerPhoneNumber = phoneNumber
            }
            // EAR feed
            .onChange(of: cameraManager.EAR) { newEAR in
                var s = earSeries
                s.append(CGFloat(newEAR))
                if s.count > earMaxSamples {
                    s.removeFirst(s.count - earMaxSamples)
                }
                earSeries = s
            }
            // Pose feed from NormalizedPoints
            .onReceive(cameraManager.$NormalizedPoints) { pts in
                if let (pitch, yaw, roll) = cameraManager.computeAngles(from: pts) {
                    var p = pitchSeries
                    p.append(CGFloat(pitch))
                    var y = yawSeries
                    y.append(CGFloat(yaw))
                    var r = rollSeries
                    r.append(CGFloat(roll))
                    
                    let cap = poseMaxSamples
                    if p.count > cap { p.removeFirst(p.count - cap) }
                    if y.count > cap { y.removeFirst(y.count - cap) }
                    if r.count > cap { r.removeFirst(r.count - cap) }
                    
                    pitchSeries = p
                    yawSeries = y
                    rollSeries = r
                }
            }
            // Trigger flash animation when new frame is recorded
            .onChange(of: cameraManager.frameRecordedTrigger) { _ in
                showRecordingFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showRecordingFlash = false
                }
            }
            // Handle successful upload - go back to ContentView
            .onChange(of: cameraManager.uploadSuccess) { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        cameraManager.resetForNewUser()
                        onComplete()  // Navigate back to ContentView
                    }
                }
            }
            .alert("Upload Status", isPresented: .constant(cameraManager.uploadError != nil || cameraManager.uploadSuccess)) {
                Button("OK") {
                    cameraManager.uploadError = nil
                    // uploadSuccess will be handled by onChange
                }
            } message: {
                if let error = cameraManager.uploadError {
                    Text("Error: \(error)")
                } else if cameraManager.uploadSuccess {
                    Text("Face pattern uploaded successfully! ✅")
                }
            }
        }
    }
    
    // Phone Number Input Overlay
    @ViewBuilder
    private func phoneNumberInputOverlay(isCompact: Bool) -> some View {
        ZStack {
            // Blur background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
                
                // Title
                VStack(spacing: 8) {
                    Text("Face Pattern Registration")
                        .font(.system(size: isCompact ? 24 : 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter phone number to begin")
                        .font(.system(size: isCompact ? 14 : 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Phone Number Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    TextField("", text: $cameraManager.FaceOwnerPhoneNumber)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .keyboardType(.phonePad)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                        )
                }
                .padding(.horizontal, 32)
                
                // Start Button
                Button {
                    if !cameraManager.FaceOwnerPhoneNumber.isEmpty {
                        withAnimation(.spring(response: 0.5)) {
                            cameraManager.hasEnteredPhoneNumber = true
                          //  showPhoneNumberInput = false
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Start Scanning")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.cyan,
                                Color.blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
                }
                .disabled(cameraManager.FaceOwnerPhoneNumber.count < 5)
                .opacity(cameraManager.FaceOwnerPhoneNumber.count < 5 ? 0.5 : 1.0)
                .padding(.horizontal, 32)
                
                // Instructions
                VStack(spacing: 12) {
                    instructionRow(icon: "1.circle.fill", text: "Look straight at the camera")
                    instructionRow(icon: "2.circle.fill", text: "Keep your head stable")
                    instructionRow(icon: "3.circle.fill", text: "Press Start when ready")
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
            .padding(.vertical, 40)
            .frame(maxWidth: isCompact ? 400 : 500)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.05, green: 0.05, blue: 0.15),
                                Color(red: 0.1, green: 0.1, blue: 0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.cyan.opacity(0.6),
                                Color.blue.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func overlayCards(screenWidth: CGFloat, screenHeight: CGFloat, isCompact: Bool) -> some View {
        let cardWidth = isCompact ? min(screenWidth * 0.6, 240) : min(screenWidth * 0.18, 260)
        let cardHeight = isCompact ? min(screenHeight * 0.25, 160) : min(screenHeight * 0.22, 180)
        
        // Pose graph (pitch/yaw/roll)
        PoseGraphCard(
            pitch: pitchSeries,
            yaw:   yawSeries,
            roll:  rollSeries,
            minY: poseRange.lowerBound,
            maxY: poseRange.upperBound
        )
        .frame(width: cardWidth, height: cardHeight)

        // EAR chart
        EARGraphCard(
            values: earSeries,
            minY: earRange.lowerBound,
            maxY: earRange.upperBound,
            threshold: blinkThreshold
        )
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(0.3), radius: 6)

        // Points overlay
        NormalizedPointsOverlay(
            points: cameraManager.NormalizedPoints,
            pointSize: isCompact ? 2.5 : 3.0,
            insetRatio: 0.12,
            smoothingAlpha: 0.25
        )
        .frame(width: cardWidth, height: cardHeight)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 6)
    }
}
