//
//  SlideToLogoutButton.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 07.11.2025.
//  Performance optimized version
//

import SwiftUI

struct SlideToLogoutButton: View {
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var offsetX: CGFloat = 0
    @State private var isCompleted = false
    @State private var hasTriggeredHaptic = false
    
    // Reusable haptic generators (created once)
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private let buttonHeight: CGFloat = 60
    private let thumbSize: CGFloat = 52
    
    var body: some View {
        GeometryReader { geometry in
            let maxOffset = geometry.size.width - thumbSize - 8
            let progress = offsetX / maxOffset
            
            ZStack(alignment: .leading) {
                // Background with optimized gradient
                RoundedRectangle(cornerRadius: 30)
                    .fill(backgroundGradient(progress: progress))
                    .shadow(
                        color: isDisabled ? .clear : Color.red.opacity(0.3),
                        radius: 15,
                        y: 8
                    )
                    .drawingGroup() // Optimizes shadow rendering
                
                // Progress fill
                if !isDisabled {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: offsetX + thumbSize)
                }
                
                // Text label
                HStack {
                    Spacer()
                    Text("Slide to Logout")
                       // .font(.system(size: 16, weight: .semibold, design: .rounded))
//                        .foregroundColor(isDisabled ? .gray : .black.opacity(0.9))
//                        .opacity(1 - progress * 1.5)
                    Spacer()
                }
                
                // Sliding thumb
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 2, y: 2)
                        
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(thumbColor(progress: progress))
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: offsetX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isDisabled && !isCompleted else { return }
                                
                                // Direct update without animation for smooth dragging
                                let newOffset = max(0, min(value.translation.width, maxOffset))
                                offsetX = newOffset
                                
                                // Haptic feedback when reaching the end (only once)
                                if newOffset >= maxOffset * 0.95 && !hasTriggeredHaptic {
                                    impactGenerator.impactOccurred()
                                    hasTriggeredHaptic = true
                                }
                                
                                // Reset haptic flag when dragging back
                                if newOffset < maxOffset * 0.9 {
                                    hasTriggeredHaptic = false
                                }
                            }
                            .onEnded { _ in
                                guard !isDisabled && !isCompleted else { return }
                                
                                if offsetX >= maxOffset * 0.85 {
                                    // Complete the action
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        offsetX = maxOffset
                                    }
                                    isCompleted = true
                                    
                                    // Success haptic
                                    notificationGenerator.notificationOccurred(.success)
                                    
                                    // Trigger action after animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        action()
                                    }
                                } else {
                                    // Reset with spring animation
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        offsetX = 0
                                    }
                                }
                                
                                // Reset haptic flag
                                hasTriggeredHaptic = false
                            }
                    )
                    
                    Spacer()
                }
                .padding(4)
            }
            .frame(height: buttonHeight)
        }
        .frame(height: buttonHeight)
        .onAppear {
            // Prepare haptic generators
            impactGenerator.prepare()
            notificationGenerator.prepare()
        }
    }
    
    // MARK: - Helper Functions
    
    private func backgroundGradient(progress: CGFloat) -> LinearGradient {
        if isDisabled {
            return LinearGradient(
                colors: [Color.gray.opacity(0.3 + progress * 0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.red.opacity(0.3 + progress * 0.7),
                    Color.red.opacity(0.2 + progress * 0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func thumbColor(progress: CGFloat) -> Color {
        if isDisabled {
            return .gray
        } else {
            return progress > 0.8 ? .green : .red
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        SlideToLogoutButton(isDisabled: false) {
            print("Logged out!")
        }
        .padding()
        
        SlideToLogoutButton(isDisabled: true) {
            print("This won't trigger")
        }
        .padding()
    }
}
