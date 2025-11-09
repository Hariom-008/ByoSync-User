//import Foundation
//import SwiftUI
//
//struct UserCard: View {
//    @EnvironmentObject var userSession: UserSession
//    
//    var body: some View {
//        ZStack(alignment: .trailing) {
//            RoundedRectangle(cornerRadius: 28, style: .continuous)
//                .fill(Color.white.opacity(0.05))
//                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 28, style: .continuous)
//                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
//                )
//            
//            HStack(spacing: 16) {
//                VStack(alignment: .leading, spacing: 6) {
//                    // Display actual user's first and last name
//                    Text(userSession.fullName)
//                        .font(.headline).bold()
//                        .foregroundColor(.white)
//                    
//                    // Display actual phone number
//                    Text("\(userSession.phoneNumber)")
//                        .font(.caption)
//                        .foregroundColor(.white.opacity(0.85))
//                    
//                    // Display ByoSync ID based on phone number
//                    Text(userSession.byoSyncId)
//                        .font(.caption)
//                        .foregroundColor(.white.opacity(0.85))
//                }
//                Spacer()
//                
//                // avatar with scan badge
//                ZStack(alignment: .bottomLeading) {
//                    // You can add user profile image here if available
//                    Image("sampleDP")
//                        .resizable()
//                        .scaledToFill()
//                        .frame(width: 62, height: 62)
//                        .clipShape(Circle())
//                        .overlay(
//                            Circle().stroke(Color.white.opacity(0.35), lineWidth: 3)
//                        )
//                }
//            }
//            .padding(18)
//        }
//        .frame(height: 110)
//    }
//}
//
//#Preview {
//    UserCard()
//        .environmentObject(UserSession.shared)
//        .padding()
//        .background(Color(hex: "4B548D"))
//}
