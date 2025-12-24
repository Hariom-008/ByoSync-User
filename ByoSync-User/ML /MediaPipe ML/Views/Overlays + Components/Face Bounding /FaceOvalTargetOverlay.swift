import SwiftUI

struct TargetFaceOvalOverlay: View {
    @ObservedObject var faceManager: FaceManager

    var body: some View {
        Canvas { context, size in
            let points = faceManager.TransalatedScaledFaceOvalCoordinates
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for i in 1..<points.count {
                path.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
            }
            path.closeSubpath()

            let isAligned = faceManager.isNoseTipCentered && faceManager.isHeadPoseStable()
            let color: Color
            if !faceManager.iodIsValid {
                color = .red.opacity(0.8)
            } else if isAligned {
                color = .green.opacity(0.8)
            } else {
                color = .yellow.opacity(0.8)
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
