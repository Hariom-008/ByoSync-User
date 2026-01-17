import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager
    
    // MARK: - Thresholds
    private let IOD_NORM_MAX: Float = 0.22
    
    private let REG_CENTER_PITCH_THR: Float = 0.12
    private let REG_CENTER_YAW_THR: Float = 0.12
    private let REG_CENTER_ROLL_THR: Float = 0.05
    
    private let MOVE_PITCH_THR: Float = 0.12
    private let MOVE_YAW_THR: Float = 0.12
    private let MOVE_ROLL_THR: Float = 0.05
    
    private let VER_PITCH_THR: Float = 0.12
    private let VER_YAW_THR: Float = 0.12
    private let VER_ROLL_THR: Float = 0.05
    
    var body: some View {
        ZStack {
            switch faceManager.faceAuthManager.currentMode {
            case .registration:
                registrationOverlay
            case .verification:
                verificationOverlay
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Registration
    
    private var registrationOverlay: some View {
        ZStack {
            switch faceManager.registrationPhase {
            case .centerCollecting:
                registrationCenterTrackingOverlay
                
            case .movementCollecting:
                registrationMovementTrackingOverlay
                
            case .done:
                successIndicator(text: "Processing…")
            }
        }
    }
    
    // MARK: - Phase 1: Center Tracking
    
    private var registrationCenterTrackingOverlay: some View {
        let iodOk = faceManager.iodIsValid
        let iodNormOk = faceManager.iodNormalized <= IOD_NORM_MAX
        let stable = faceManager.isPoseStable(
            pitchThr: REG_CENTER_PITCH_THR,
            yawThr: REG_CENTER_YAW_THR,
            rollThr: REG_CENTER_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval
        let allOk = iodOk && iodNormOk && stable && inside
        
        print("📊 [Center Phase] IOD:\(iodOk) Norm:\(iodNormOk) Stable:\(stable) Inside:\(inside)")
        
        return ZStack {
            // Directional arrows for positioning
            if !inside || !iodNormOk {
                positioningArrows(iodOk: iodOk, iodNormOk: iodNormOk, inside: inside)
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                // Main status indicator
                if allOk {
                    capturingIndicator(
                        count: faceManager.centerFramesCount,
                        total: 60,
                        label: "Hold Steady"
                    )
                } else {
                    primaryGuidance(iodOk: iodOk, iodNormOk: iodNormOk, stable: stable, inside: inside)
                }
                
                Spacer()
                
                // Progress bar at bottom
                progressBar(current: faceManager.centerFramesCount, total: 60)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Phase 2: Movement Tracking
    
    private var registrationMovementTrackingOverlay: some View {
        let stable = faceManager.isPoseStable(
            pitchThr: MOVE_PITCH_THR,
            yawThr: MOVE_YAW_THR,
            rollThr: MOVE_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval
        let allOk = stable && inside
        
        print("🎭 [Movement Phase] Stable:\(stable) Inside:\(inside) Frames:\(faceManager.movementFramesCount)")
        
        return ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                if allOk {
                    movementCaptureIndicator(
                        count: faceManager.movementFramesCount,
                        secondsRemaining: faceManager.movementSecondsRemaining
                    )
                } else {
                    simpleGuidance(
                        text: inside ? "Hold Steady" : "Keep Face in Frame",
                        icon: "face.smiling"
                    )
                }
                
                Spacer()
                
                // Timer display at bottom
                movementTimer(seconds: faceManager.movementSecondsRemaining)
                    .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Verification
    
    private var verificationOverlay: some View {
        let iodOk = faceManager.iodIsValid
        let iodNormOk = faceManager.iodNormalized <= IOD_NORM_MAX
        let stable = faceManager.isPoseStable(
            pitchThr: VER_PITCH_THR,
            yawThr: VER_YAW_THR,
            rollThr: VER_ROLL_THR
        )
        let inside = faceManager.faceisInsideFaceOval
        let allOk = iodOk && iodNormOk && stable && inside
        
        print("🔐 [Verification] IOD:\(iodOk) Norm:\(iodNormOk) Stable:\(stable) Inside:\(inside)")
        
        return ZStack {
            // Directional arrows for positioning
            if !inside || !iodNormOk {
                positioningArrows(iodOk: iodOk, iodNormOk: iodNormOk, inside: inside)
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                if allOk {
                    successIndicator(text: "Verifying…")
                } else {
                    primaryGuidance(iodOk: iodOk, iodNormOk: iodNormOk, stable: stable, inside: inside)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Visual Components
    
    // Directional arrows based on face position
    @ViewBuilder
    private func positioningArrows(iodOk: Bool, iodNormOk: Bool, inside: Bool) -> some View {
        ZStack {
            // Distance guidance (up/down arrows)
            if iodOk && !iodNormOk {
                // Face too far - show up arrow (move closer)
                AnimatedArrow(
                    imageName: "up_arrow",
                    direction: .up,
                    message: "Move Closer"
                )
            } else if !iodOk {
                // Use IOD guidance for specific distance issues
                switch faceManager.iodGuidance {
                case .moveCloser:
                    AnimatedArrow(
                        imageName: "up_arrow",
                        direction: .up,
                        message: "Move Closer"
                    )
                case .moveFarther:
                    AnimatedArrow(
                        imageName: "down_arrow",
                        direction: .down,
                        message: "Move Back"
                    )
                default:
                    EmptyView()
                }
            }
        }
    }
    
    // Primary guidance text - shows the most important action
    @ViewBuilder
    private func primaryGuidance(iodOk: Bool, iodNormOk: Bool, stable: Bool, inside: Bool) -> some View {
        VStack(spacing: 12) {
            // Prioritize guidance: distance > position > stability
            if !iodOk || !iodNormOk {
                guidancePill(
                    text: getDistanceGuidance(iodOk: iodOk, iodNormOk: iodNormOk),
                    icon: "arrow.up.and.down.circle.fill",
                    color: .orange
                )
            } else if !inside {
                guidancePill(
                    text: "Center Your Face",
                    icon: "circle.dashed",
                    color: .yellow
                )
            } else if !stable {
                guidancePill(
                    text: "Hold Steady",
                    icon: "hand.raised.fill",
                    color: .blue
                )
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inside)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stable)
    }
    
    // Simple guidance for movement phase
    @ViewBuilder
    private func simpleGuidance(text: String, icon: String) -> some View {
        guidancePill(
            text: text,
            icon: icon,
            color: .blue
        )
    }
    
    // Guidance pill component
    @ViewBuilder
    private func guidancePill(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // Capturing indicator with circular progress
    @ViewBuilder
    private func capturingIndicator(count: Int, total: Int, label: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: count)
                
                // Checkmark icon
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            Text("\(count)/\(total)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // Movement capture indicator
    @ViewBuilder
    private func movementCaptureIndicator(count: Int, secondsRemaining: Int) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Move Naturally")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(count) frames captured")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // Success indicator
    @ViewBuilder
    private func successIndicator(text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.green.opacity(0.9))
        )
    }
    
    // Progress bar at bottom
    @ViewBuilder
    private func progressBar(current: Int, total: Int) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(current) / CGFloat(total), height: 8)
                        .animation(.linear(duration: 0.1), value: current)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 40)
        }
    }
    
    // Movement timer
    @ViewBuilder
    private func movementTimer(seconds: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(seconds)s remaining")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Helper Functions
    
    private func getDistanceGuidance(iodOk: Bool, iodNormOk: Bool) -> String {
        print("🎯 [Distance] IOD OK: \(iodOk), Norm OK: \(iodNormOk)")
        
        if !iodOk {
            switch faceManager.iodGuidance {
            case .moveCloser: return "Move Closer"
            case .moveFarther: return "Move Back"
            case .ok: return "Perfect Distance"
            case .noFace: return "Position Your Face"
            }
        }
        
        if !iodNormOk {
            return "Move Closer"
        }
        
        return "Adjust Distance"
    }
}

// MARK: - Animated Arrow Component

struct AnimatedArrow: View {
    let imageName: String
    let direction: ArrowDirection
    let message: String
    
    @State private var offset: CGFloat = 0
    
    enum ArrowDirection {
        case up, down, left, right
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if direction == .down {
                Text(message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
            }
            
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .offset(y: direction == .up ? offset : -offset)
                .opacity(0.9)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset = 10
                    }
                }
            
            if direction == .up {
                Text(message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: direction == .up ? .bottom : .top)
        .padding(.vertical, direction == .up ? 200 : 150)
    }
}
