import SwiftUI

struct LinkedDevicesView: View {
    @StateObject private var viewModel = GetDevicesViewModel()
    @ObservedObject private var userSession = UserSession.shared

    // Alert states
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    // Confirmation state
    @State private var showUnlinkConfirm = false
    @State private var unlinkAction: (() -> Void)?
    @State private var deviceToUnlink: DeviceData?

    private let debugMode = false
    
    // MARK: - Session Abstraction
    private var sessionProvider: SessionProvider {
        SessionProvider(userSession: userSession)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                Group {
                    // MARK: - Loading State
                    if viewModel.isLoading && viewModel.devices.isEmpty {
                        LoadingStateView()
                    } else if viewModel.devices.isEmpty && !viewModel.isLoading {
                        EmptyDevicesView()
                    } else {
                        // MARK: - Device List
                        ScrollView {
                            VStack(spacing: 16) {
                                // Info banner
                                ModernInfoBanner()
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)

                                // Device cards
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.devices) { device in
                                        ModernDeviceCard(
                                            device: device,
                                            isCurrentDevice: sessionProvider.isCurrentDevice(device),
                                            isThisDevicePrimary: sessionProvider.isThisDevicePrimary(),
                                            onMakePrimary: {
                                                HapticManager.impact(style: .medium)
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    viewModel.changePrimaryDevice(to: device.id)
                                                }
                                            },
                                            onUnlinkDevice: {
                                                HapticManager.impact(style: .light)
                                                deviceToUnlink = device
                                                unlinkAction = {
                                                    viewModel.unlinkOtherDevice(deviceId: device.id)
                                                }
                                                showUnlinkConfirm = true
                                            }
                                        )
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 8)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.devices.count)
                    }
                }

                if viewModel.isLoading && !viewModel.devices.isEmpty {
                    VStack {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                            Text("Updating...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        Spacer()
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Linked Devices")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation {
                    viewModel.fetchUserDevices()
                }
            }
            .refreshable {
                HapticManager.impact(style: .light)
                await viewModel.fetchUserDevices()
            }

            // Alerts
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    HapticManager.impact(style: .light)
                }
            } message: {
                Text(alertMessage)
            }
            .alert("Unlink Device", isPresented: $showUnlinkConfirm) {
                Button("Cancel", role: .cancel) {
                    HapticManager.impact(style: .light)
                }
                Button("Unlink", role: .destructive) {
                    HapticManager.impact(style: .medium)
                    unlinkAction?()
                }
            } message: {
                Text(getUnlinkMessage())
            }

            // Alert triggers
            .onChange(of: viewModel.successMessage) { oldValue, newValue in
                if let message = newValue {
                    HapticManager.notification(type: .success)
                    showMessageAlert(title: "Success", message: message)
                    viewModel.successMessage = nil
                }
            }
            .onChange(of: viewModel.errorMessage) { oldValue, newValue in
                if let message = newValue {
                    HapticManager.notification(type: .error)
                    showMessageAlert(title: "Error", message: message)
                    viewModel.errorMessage = nil
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func getUnlinkMessage() -> String {
        if let device = deviceToUnlink {
            return "Are you sure you want to unlink '\(device.deviceName)'? You'll need to sign in again on that device."
        } else if sessionProvider.isThisDevicePrimary() {
            return "This will unlink all other devices linked to your account."
        } else {
            return "This will unlink this device from your account. You'll need to sign in again."
        }
    }

    private func showMessageAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Session Provider (Abstraction Layer)
struct SessionProvider {
    private let userSession: UserSession
    
    init(userSession: UserSession) {
        self.userSession = userSession
    }
    
    
    /// Get the current device ID from the appropriate session
    private var currentDeviceID: String {
            return userSession.currentUserDeviceID
        }
    
    /// Check if the current device is primary
    func isThisDevicePrimary() -> Bool {
            return userSession.thisDeviceIsPrimary
        }
    
    /// Check if a given device is the current device
    func isCurrentDevice(_ device: DeviceData) -> Bool {
        return device.id == currentDeviceID
    }
}


// MARK: - Loading State View
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.3)
            
            
            VStack(spacing: 8) {
                Text("Loading Devices")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Please wait while we fetch your devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Empty Devices View
struct EmptyDevicesView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("No Linked Devices")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Your devices will appear here once you sign in on other devices")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }
}

// MARK: - Modern Info Banner
struct ModernInfoBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Primary Device")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Only the primary device can manage other devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Modern Device Card
struct ModernDeviceCard: View {
    let device: DeviceData
    let isCurrentDevice: Bool
    let isThisDevicePrimary: Bool
    let onMakePrimary: () -> Void
    let onUnlinkDevice: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section with device info
            HStack(spacing: 14) {
                // Device icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    deviceIconColor.opacity(0.2),
                                    deviceIconColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: deviceIcon)
                        .font(.system(size: 26))
                        .foregroundStyle(deviceIconColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(device.deviceName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Status badges
                    HStack(spacing: 8) {
                        if device.isPrimary {
                            StatusBadge(
                                text: "Primary",
                                icon: "star.fill",
                                color: .blue
                            )
                        }
                        
                        if isCurrentDevice {
                            StatusBadge(
                                text: "This Device",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                        }
                    }
                    
                    // Last updated
                    if let lastUpdated = formatDate(device.updatedAt) {
                        Text("Updated \(lastUpdated)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            
            // Action buttons section
            if shouldShowActions {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack(spacing: 10) {
                    // Make Primary button
                    if !device.isPrimary && isThisDevicePrimary {
                        ModernActionButton(
                            title: "Make Primary",
                            icon: "star.fill",
                            color: .blue,
                            style: .bordered,
                            action: onMakePrimary
                        )
                    }
                    
                    // Unlink button
                    if shouldShowUnlinkButton && canUnlink {
                        ModernActionButton(
                            title: "Unlink",
                            icon: "trash.fill",
                            color: .red,
                            style: device.isPrimary ? .filled : .bordered,
                            action: onUnlinkDevice
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
    
    // MARK: - Computed Properties
    
    private var deviceIcon: String {
        let name = device.deviceName.lowercased()
        if name.contains("iphone") {
            return "iphone.gen3"
        } else if name.contains("ipad") {
            return "ipad.gen2"
        } else if name.contains("mac") {
            return "laptopcomputer"
        } else if name.contains("watch") {
            return "applewatch"
        } else {
            return "iphone.gen3"
        }
    }
    
    private var deviceIconColor: Color {
        if device.isPrimary {
            return .blue
        } else if isCurrentDevice {
            return .green
        } else {
            return .gray
        }
    }
    
    private var shouldShowActions: Bool {
        return !device.isPrimary || isCurrentDevice
    }
    
    private var shouldShowUnlinkButton: Bool {
        return !device.isPrimary
    }
    
    private var canUnlink: Bool {
        return isCurrentDevice || isThisDevicePrimary
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return nil }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Modern Action Button
struct ModernActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let style: ButtonDisplayStyle
    let action: () -> Void
    
    enum ButtonDisplayStyle {
        case filled
        case bordered
    }
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if style == .filled {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(color.opacity(0.1))
                        }
                    }
                )
                .foregroundColor(style == .filled ? .white : color)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Haptic Manager
struct HapticManager {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

#Preview {
    LinkedDevicesView()
}
