import SwiftUI

struct MLScanView: View {
    var onDone: () -> Void
    let userId:String
    let deviceKeyHash: String
    
    @EnvironmentObject var faceAuthManager: FaceAuthManager
    
    var body: some View {
        FaceDetectionView(authToken: UserDefaults.standard.string(forKey: "token") ?? "",onComplete: {
            DispatchQueue.main.async {
                onDone()
            }
        },
        userId: userId, deviceKeyHash: deviceKeyHash
        )
        .navigationBarHidden(true)
    }
}
