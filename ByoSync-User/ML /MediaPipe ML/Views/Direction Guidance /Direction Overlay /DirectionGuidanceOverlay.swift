import SwiftUI

struct DirectionalGuidanceOverlay: View {
    @ObservedObject var faceManager: FaceManager

    // Match Android thresholds
    private let PITCH_THRESHOLD: Float = 0.12
    private let YAW_THRESHOLD: Float = 0.12
    private let ROLL_THRESHOLD: Float = 0.05

    var body: some View {
        ZStack {
            // Priority 1: Show stable indicator when everything is perfect
            if allConditionsMet {
                stableIndicator
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            // Priority 2: Show IOD distance guidance when not stable
            else if !faceManager.iodIsValid {
                distanceGuidanceText
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
            // Directional arrows (shown when pose needs correction)
            if !poseIsCentered {
                directionalArrows
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: allConditionsMet)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: faceManager.iodIsValid)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: poseIsCentered)
        .allowsHitTesting(false)
    }

    // MARK: - Gates

    private var allConditionsMet: Bool {
        print("✅ [Gates] IOD:\(faceManager.iodIsValid) Pose:\(poseIsCentered) Stable:\(faceManager.isHeadPoseStable())")
        return faceManager.iodIsValid &&
               poseIsCentered &&
               faceManager.isHeadPoseStable()
    }

    private var poseIsCentered: Bool {
        let centered = abs(faceManager.Pitch) <= PITCH_THRESHOLD &&
                      abs(faceManager.Yaw) <= YAW_THRESHOLD &&
                      abs(faceManager.Roll) <= ROLL_THRESHOLD
        
        print("🎯 [Pose Check] P:\(String(format: "%.3f", faceManager.Pitch)) Y:\(String(format: "%.3f", faceManager.Yaw)) R:\(String(format: "%.3f", faceManager.Roll)) → \(centered ? "✓" : "✗")")
        return centered
    }

    // MARK: - Stable Indicator (Priority 1)

    private var stableIndicator: some View {
        VStack {
            Spacer().frame(height: 120) // Match Android's 120dp top padding
            
            HStack(spacing: 10) {
                Text("✓")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.green)
                    .modifier(GlowPulseModifier())
                
                Text("Hold steady")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.37, blue: 0.13).opacity(0.95)) // #1B5E20
            )
            
            Spacer()
        }
    }

    // MARK: - Distance Guidance Text (Priority 2)

    private var distanceGuidanceText: some View {
        VStack {
            Spacer().frame(height: 120) // Match Android's 120dp top padding
            
            Text(distanceText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(distanceColor)
                .modifier(PulseOpacityModifier())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.6))
                )
            
            Spacer()
        }
    }

    private var distanceText: String {
        print("📏 [Distance] Guidance: \(faceManager.iodGuidance)")
        switch faceManager.iodGuidance {
        case .moveCloser:
            return "Move closer"
        case .moveFarther:
            return "Move back"
        case .ok:
            return "Perfect distance"
        case .noFace:
            return "Position your face"
        }
    }

    private var distanceColor: Color {
        switch faceManager.iodGuidance {
        case .ok:
            return Color(red: 0.30, green: 0.69, blue: 0.31) // #4CAF50
        case .moveCloser, .moveFarther, .noFace:
            return Color(red: 1.0, green: 0.32, blue: 0.32) // #FF5252
        }
    }

    // MARK: - Directional Arrows (Fixed Positions)

    private var directionalArrows: some View {
        ZStack {
            // Pitch: Up arrow (top center)
            if faceManager.Pitch < -PITCH_THRESHOLD {
                AnimatedArrow(
                    imageName: "up_arrow",
                    alignment: .top,
                    offset: CGPoint(x: 0, y: 500)
                )
            }

            // Pitch: Down arrow (bottom center)
            if faceManager.Pitch > PITCH_THRESHOLD {
                AnimatedArrow(
                    imageName: "down_arrow",
                    alignment: .bottom,
                    offset: CGPoint(x: 0, y: -500)
                )
            }

            // Yaw: Left arrow (left center)
            if faceManager.Yaw > YAW_THRESHOLD {
                AnimatedArrow(
                    imageName: "left_arrow",
                    alignment: .leading,
                    offset: CGPoint(x: 20, y: 0)
                )
            }

            // Yaw: Right arrow (right center)
            if faceManager.Yaw < -YAW_THRESHOLD {
                AnimatedArrow(
                    imageName: "right_arrow",
                    alignment: .trailing,
                    offset: CGPoint(x: -20, y: 0)
                )
            }

            // Roll: Tilt left (top-start)
            if faceManager.Roll > ROLL_THRESHOLD {
                AnimatedArrow(
                    imageName: "round_right_arrow",
                    alignment: .topLeading,
                    offset: CGPoint(x: 16, y: 100)
                )
            }

            // Roll: Tilt right (top-end)
            if faceManager.Roll < -ROLL_THRESHOLD {
                AnimatedArrow(
                    imageName: "round_left_arrow",
                    alignment: .topTrailing,
                    offset: CGPoint(x: -16, y: 100)
                )
            }
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
