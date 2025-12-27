//
//  Nose Tip.swift
//  ML-Testing
//
//  Created by Hari's Mac on 29.11.2025.
//

//import Foundation
//import SwiftUI
//
//extension FaceManager {
//    func  updateNoseTipCenterStatusFromCalcCoords(tolerance: Float = 0.05) {
//        guard CalculationCoordinates.count > 4 else {
//            isNoseTipCentered = false
//            return
//        }
//        let nose = CalculationCoordinates[4] // (0..1)
//        isNoseTipCentered = abs(nose.x - 0.5) <= tolerance &&
//                            abs(nose.y - 0.5) <= tolerance
//    }
//}


import SwiftUI
import Foundation
import CoreGraphics

extension FaceManager {

    /// Android-equivalent: pixel coordinates + Euclidean distance + pixel tolerance
    func updateNoseTipCenterStatusFromCalcCoords(
        pixelPoints: [CGPoint],
        screenCenterX: CGFloat,
        screenCenterY: CGFloat,
        tolerancePx: CGFloat = 10.0
    ){
        guard pixelPoints.count > 4 else {
            self.isNoseTipCentered = false
            return
        }

        let nose = pixelPoints[4]
        let dx = nose.x - screenCenterX
        let dy = nose.y - screenCenterY
        let distance = sqrt(dx * dx + dy * dy)

        self.isNoseTipCentered = distance <= tolerancePx
    }
}
