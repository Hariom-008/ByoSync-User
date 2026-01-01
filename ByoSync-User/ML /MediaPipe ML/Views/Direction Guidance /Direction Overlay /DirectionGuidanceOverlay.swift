import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager

    // Center-stability thresholds
    private let CENTER_PITCH_THR: Float = 0.10
    private let CENTER_YAW_THR:   Float = 0.10
    private let ROLL_THR:         Float = 0.05

    var body: some View {
        ZStack {
            if !faceManager.iodIsValid {
                distanceGuidanceText
            } else {
                switch faceManager.faceAuthManager.currentMode{
                case .registration:
                    registrationOverlay
                case .verification:
                    verificationOverlay
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Registration

    private var registrationOverlay: some View {
        ZStack {
            switch faceManager.registrationPhase {
            case .centerCollecting:
                // no nose gate here
                if faceManager.isPoseStable(pitchThr: CENTER_PITCH_THR, yawThr: CENTER_YAW_THR, rollThr: ROLL_THR) {
                    stablePill(text: "Hold steady • \(faceManager.centerFramesCount)/60")
                } else {
                    centerCorrectionArrows
                    topPill(text: "Center your face • \(faceManager.centerFramesCount)/60")
                }

            case .movementCollecting:
                movementTargetUI

            case .done:
                stablePill(text: "Processing…")
            }
        }
    }

    private var movementTargetUI: some View {
        let target = faceManager.currentTarget
        let dirNow = classifyDirection(pitch: faceManager.Pitch, yaw: faceManager.Yaw)

        return ZStack {
            topPill(text: "Move head • \(faceManager.movementSecondsRemaining)s")

            VStack {
                Spacer().frame(height: 170)

                Text("Look \(label(target))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.65)))

                if abs(faceManager.Roll) > ROLL_THR {
                    Text("Keep your head straight")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.top, 6)
                } else if dirNow == target {
                    Text("✓ Captured")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.top, 6)
                }

                Spacer()
            }

            movementArrows(for: target)
        }
    }

    private func movementArrows(for target: HeadDirection) -> some View {
        ZStack {
            switch target {
            case .left:
                AnimatedArrow(imageName: "left_arrow", alignment: .leading, offset: CGPoint(x: 20, y: 0))
            case .right:
                AnimatedArrow(imageName: "right_arrow", alignment: .trailing, offset: CGPoint(x: -20, y: 0))
            case .up:
                AnimatedArrow(imageName: "up_arrow", alignment: .top, offset: CGPoint(x: 0, y: 500))
            case .down:
                AnimatedArrow(imageName: "down_arrow", alignment: .bottom, offset: CGPoint(x: 0, y: -500))
            case .center:
                EmptyView()
            }
        }
    }

    private var centerCorrectionArrows: some View {
        // Same style as your existing arrows, but centered-threshold based
        ZStack {
            if faceManager.Pitch < -CENTER_PITCH_THR {
                AnimatedArrow(imageName: "up_arrow", alignment: .top, offset: CGPoint(x: 0, y: 500))
            }
            if faceManager.Pitch > CENTER_PITCH_THR {
                AnimatedArrow(imageName: "down_arrow", alignment: .bottom, offset: CGPoint(x: 0, y: -500))
            }
            if faceManager.Yaw > CENTER_YAW_THR {
                AnimatedArrow(imageName: "left_arrow", alignment: .leading, offset: CGPoint(x: 20, y: 0))
            }
            if faceManager.Yaw < -CENTER_YAW_THR {
                AnimatedArrow(imageName: "right_arrow", alignment: .trailing, offset: CGPoint(x: -20, y: 0))
            }
            if faceManager.Roll > ROLL_THR {
                AnimatedArrow(imageName: "round_right_arrow", alignment: .topLeading, offset: CGPoint(x: 16, y: 100))
            }
            if faceManager.Roll < -ROLL_THR {
                AnimatedArrow(imageName: "round_left_arrow", alignment: .topTrailing, offset: CGPoint(x: -16, y: 100))
            }
        }
    }

    // MARK: - Verification (keep your previous behavior)

    private var verificationOverlay: some View {
        ZStack {
            // show "hold steady" only if stable + centered-ish (your old logic)
            if faceManager.isPoseStable(pitchThr: 0.12, yawThr: 0.12, rollThr: 0.05) {
                stablePill(text: "Hold steady")
            } else {
                centerCorrectionArrows
                topPill(text: "Align your face")
            }
        }
    }

    // MARK: - IOD Guidance

    private var distanceGuidanceText: some View {
        VStack {
            Spacer().frame(height: 120)
            Text(distanceText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(distanceColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.6)))
            Spacer()
        }
    }

    private var distanceText: String {
        switch faceManager.iodGuidance {
        case .moveCloser: return "Move closer"
        case .moveFarther: return "Move back"
        case .ok: return "Perfect distance"
        case .noFace: return "Position your face"
        }
    }

    private var distanceColor: Color {
        switch faceManager.iodGuidance {
        case .ok: return .green
        default: return .red
        }
    }

    // MARK: - UI helpers

    private func label(_ d: HeadDirection) -> String {
        switch d {
        case .left: return "LEFT"
        case .right: return "RIGHT"
        case .up: return "UP"
        case .down: return "DOWN"
        case .center: return "CENTER"
        }
    }

    private func topPill(text: String) -> some View {
        VStack {
            Spacer().frame(height: 120)
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.65)))
            Spacer()
        }
    }

    private func stablePill(text: String) -> some View {
        VStack {
            Spacer().frame(height: 120)
            Text("✓ \(text)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.green.opacity(0.85)))
            Spacer()
        }
    }
}


// MARK: - Animated Arrow Component

struct AnimatedArrow: View {
    let imageName: String
    let alignment: Alignment
    let offset: CGPoint
    
    var body: some View {
        VStack {
            if alignment == .top || alignment == .topLeading || alignment == .topTrailing {
                Spacer().frame(height: offset.y)
            } else if alignment == .leading || alignment == .trailing {
                Spacer()
            }
            
            HStack {
                if alignment == .leading || alignment == .topLeading {
                    Spacer().frame(width: offset.x)
                } else if alignment == .trailing || alignment == .topTrailing || alignment == .bottom || alignment == .top {
                    Spacer()
                }
                
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .modifier(ArrowPulseModifier())
                
                if alignment == .trailing || alignment == .topTrailing {
                    Spacer().frame(width: -offset.x)
                } else if alignment == .leading || alignment == .topLeading || alignment == .bottom || alignment == .top {
                    Spacer()
                }
            }
            
            if alignment == .bottom {
                Spacer().frame(height: -offset.y)
            } else if alignment == .leading || alignment == .trailing {
                Spacer()
            }
        }
    }
}

// MARK: - Animation Modifiers

struct PulseOpacityModifier: ViewModifier {
    @State private var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}

struct ArrowPulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                    opacity = 1.0
                }
            }
    }
}

struct GlowPulseModifier: ViewModifier {
    @State private var opacity: Double = 0.5
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 1.0
                }
            }
    }
}
