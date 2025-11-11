//
//  EmailVerificationView.swift
//  ByoSync
//
//  Created by Hari's Mac on 22.10.2025.
//

import SwiftUI

struct EmailVerificationView: View {
    @StateObject private var viewModel = EmailVerificationViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // OTP Verification Section Only
                    Section("Enter OTP") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("We've sent a 6-digit verification code to your email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(UserSession.shared.currentUser?.email ?? "")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "4B548D"))
                        }
                        .padding(.bottom, 4)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Color(hex: "4B548D"))
                                .frame(width: 24)
                            
                            TextField("Enter 6-digit OTP", text: $viewModel.otp)
                                .keyboardType(.numberPad)
                                .disabled(viewModel.isLoading)
                                .onChange(of: viewModel.otp) { newValue in
                                    // Limit to 6 digits
                                    if newValue.count > 6 {
                                        viewModel.otp = String(newValue.prefix(6))
                                    }
                                }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section {
                        Button(action: {
                            viewModel.verifyOTP()
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.isVerifyingOTP {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Verify OTP")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!viewModel.isOTPValid || viewModel.isLoading)
                        
                        // Resend OTP Button
                        Button(action: {
                            viewModel.resendOTP()
                        }) {
                            HStack {
                                Spacer()
                                if viewModel.canResendOTP {
                                    Text("Resend OTP")
                                        .foregroundColor(Color(hex: "4B548D"))
                                } else {
                                    Text("Resend OTP in \(viewModel.resendTimer)s")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!viewModel.canResendOTP || viewModel.isLoading)
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text(viewModel.isVerifyingOTP ? "Verifying..." : "Processing...")
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    }
                    .padding(24)
                    .background(Color(hex: "4B548D"))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("Email Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {
                    if viewModel.emailVerified {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

#Preview {
    EmailVerificationView()
}
