//
//  Nose Tip.swift
//  ML-Testing
//
//  Created by Hari's Mac on 29.11.2025.
//

import Foundation
import SwiftUI

extension FaceManager {
    // MARK: Replace Calc Coordinates with ScreenCoordinates 
    func  updateNoseTipCenterStatusFromCalcCoords(tolerance: Float = 0.05) {
        guard rawMediaPipePoints.count > 4 else {
            isNoseTipCentered = false
            return
        }
        let nose = rawMediaPipePoints[4] // (0..1)
        isNoseTipCentered = abs(nose.x - 0.5) <= tolerance &&
                            abs(nose.y - 0.5) <= tolerance
    }
}
