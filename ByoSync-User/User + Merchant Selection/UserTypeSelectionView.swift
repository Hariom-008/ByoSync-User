//import SwiftUI
//
//enum UserType {
//    case user
//    case merchant
//}
//
//struct UserTypeSelectionView: View {
//    @State private var selectedType: UserType = .user
//    @State private var isAnimating = false
//    @State private var logoScale: CGFloat = 0.5
//    @State private var logoOpacity: Double = 0
//    @State private var cardOffset: CGFloat = 100
//    @State private var showContent = false
//    @State private var openNextScreen = false
//    @State var openTestinLang:Bool = false
//    @State var testing :Bool = false
//    
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                backgroundView
//                contentView
//            }
//            .onAppear {
//                startAnimations()
//            }
//            .navigationDestination(isPresented: $openNextScreen) {
//                destinationView
//            }
//        }
//    }
//    
//    // MARK: - Background
//    private var backgroundView: some View {
//        ZStack {
//            animatedCircle1
//            animatedCircle2
//        }
//    }
//    
//    private var backgroundGradient: some View {
//        LinearGradient(
//            gradient: Gradient(colors: [
//                Color(red: 0.29, green: 0.33, blue: 0.55),
//                Color(red: 0.35, green: 0.39, blue: 0.65)
//            ]),
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
//        
//        .ignoresSafeArea()
//    }
//    
//    private var animatedCircle1: some View {
//        Circle()
//            .fill(Color.white.opacity(0.05))
//            .frame(width: 300, height: 300)
//            .offset(x: -150, y: -200)
//            .blur(radius: 30)
//            .scaleEffect(isAnimating ? 1.2 : 1.0)
//            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
//    }
//    
//    private var animatedCircle2: some View {
//        Circle()
//            .fill(Color.white.opacity(0.05))
//            .frame(width: 250, height: 250)
//            .offset(x: 150, y: 250)
//            .blur(radius: 30)
//            .scaleEffect(isAnimating ? 1.0 : 1.2)
//            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isAnimating)
//    }
//    
//    // MARK: - Content
//    private var contentView: some View {
//        VStack(spacing: 0) {
//            Spacer()
//            logoSection
//           // selectionCards
//            Spacer()
//            continueButton
//            footerText
//        }
//    }
//    
//    private var logoSection: some View {
//        VStack(spacing: 16) {
//            ZStack {
//                logoImage
//            }
//            appNameText
//            subtitleText
//        }
//        .padding(.bottom, 60)
//    }
//
//    
//    
//    private var logoImage: some View {
//        ZStack {
//            Circle()
//                .fill(Color.white)
//                .frame(width: 120, height: 120)
//                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
//            
//            Image("logo")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 90, height: 90)
//                .foregroundColor(Color(red: 0.29, green: 0.33, blue: 0.55))
//        }
//        .scaleEffect(logoScale)
//        .opacity(logoOpacity)
//    }
//    
//    private var appNameText: some View {
//        Text("ByoSync")
//            .font(.system(size: 36, weight: .bold, design: .rounded))
//            .foregroundColor(.black)
//            .opacity(logoOpacity)
//    }
//    
//    private var subtitleText: some View {
//        Text("Your Account Type")
//            .font(.system(size: 16, weight: .medium))
//            .foregroundColor(.black.opacity(0.8))
//            .opacity(showContent ? 1 : 0)
//            .offset(y: showContent ? 0 : 20)
//    }
//    
////    private var selectionCards: some View {
////        VStack(spacing: 20) {
////            userCard
////        }
////        .padding(.horizontal, 24)
////    }
//    
////    private var userCard: some View {
////        UserTypeCard(
////            type: .user,
////            icon: "person.fill",
////            title: "Personal",
////            subtitle: "For personal payments",
////            isSelected: selectedType == .user
////        ) {
////            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
////                selectedType = .user
////            }
////        }
////        .opacity(showContent ? 1 : 0)
////        .offset(x: showContent ? 0 : -50)
////    }
//    
//    private var continueButton: some View {
//        Button(action: {
//            openNextScreen = true
//        }) {
//            continueButtonContent
//        }
//        .disabled(!showContent) // disable the button untill animation is showing up 
//        .padding(.horizontal, 24)
//        .padding(.bottom, 40)
//        .opacity(showContent ? 1 : 0)
//        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedType)
//    }
//    
//    private var continueButtonContent: some View {
//        HStack(spacing: 12) {
//            Text("Continue")
//                .font(.system(size: 18, weight: .semibold))
//        }
//        .frame(maxWidth: .infinity)
//        .padding(.vertical, 16)
//        .background(continueButtonBackground)
//        .foregroundColor(continueButtonForeground)
//        .cornerRadius(16)
//    }
//    
//    private var continueButtonBackground: Color {
//        Color(hex: "4B548D")
//    }
//    
//    private var continueButtonForeground: Color {
//         Color.white
//    }
//    
//    private var footerText: some View {
//        HStack(spacing: 8) {
//            Text("powered by")
//                .font(.caption2)
//                .foregroundColor(.gray.opacity(0.7))
//            Text("Kavion")
//                .font(.caption)
//                .fontWeight(.semibold)
//                .foregroundColor(.gray)
//        }
//    }
//    
//    private var destinationView: some View {
//        Group {
//            if selectedType == .user {
//              AuthenticationView(selectedUser: $selectedType)
//            }
//        }
//    }
//    
//    // MARK: - Animations
//    private func startAnimations() {
//        withAnimation(.easeOut(duration: 0.8)) {
//            logoScale = 1.0
//            logoOpacity = 1.0
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//            isAnimating = true
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
//            withAnimation(.easeOut(duration: 0.6)) {
//                showContent = true
//                cardOffset = 0
//            }
//        }
//    }
//}
//
//// MARK: - User Type Card Component
////struct UserTypeCard: View {
////    let type: UserType
////    let icon: String
////    let title: String
////    let subtitle: String
////    let isSelected: Bool
////    let action: () -> Void
////    
////    var body: some View {
////        Button(action: action) {
////            cardContent
////        }
////        .buttonStyle(PlainButtonStyle())
////    }
////    
////    private var cardContent: some View {
////        HStack(spacing: 8) {
////            iconCircle
////            textContent
////            Spacer()
////            checkmark
////        }
////        .padding(20)
////        .background(cardBackground)
////        .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
////    }
////    
////    private var iconCircle: some View {
////        ZStack {
////            Circle()
////                .fill(isSelected ? Color(hex: "4B548D").opacity(0.8) : Color(hex: "4B548D").opacity(0.05))
////                .frame(width: 60, height: 60)
////            
////            Image(systemName: icon)
////                .font(.system(size: 26, weight: .semibold))
////                .foregroundColor(iconColor)
////        }
////    }
////    
////    private var iconColor: Color {
////        isSelected ? .white : Color(hex: "4B548D").opacity(0.7)
////    }
////    
////    private var textContent: some View {
////        VStack(alignment: .leading, spacing: 4) {
////            Text(title)
////                .font(.system(size: 16, weight: .bold))
////                .foregroundColor(.black)
////            
////            Text(subtitle)
////                .font(.system(size: 12, weight: .regular))
////                .foregroundColor(.black.opacity(0.7))
////                .lineLimit(2)
////                .multilineTextAlignment(.leading)
////        }
////    }
////    
////    private var checkmark: some View {
////        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
////            .font(.system(size: 24, weight: .semibold))
////            .foregroundColor(isSelected ? Color(hex: "4B548D") : .black.opacity(0.3))
////    }
////    
////    private var cardBackground: some View {
////        RoundedRectangle(cornerRadius: 20)
////            .fill(isSelected ? Color.black.opacity(0.15) : Color.black.opacity(0.05))
////            .overlay(cardBorder)
////    }
////    
////    private var cardBorder: some View {
////        RoundedRectangle(cornerRadius: 20)
////            .stroke(
////                isSelected ? Color(hex: "4B548D").opacity(0.4) : Color(hex: "4B548D").opacity(0.1),
////                lineWidth: isSelected ? 2 : 1
////            )
////    }
////    
////    private var shadowColor: Color {
////        isSelected ? .black.opacity(0.2) : .clear
////    }
////}
//
//#Preview {
//    UserTypeSelectionView()
//}
