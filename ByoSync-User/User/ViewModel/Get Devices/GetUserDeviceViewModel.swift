import Foundation
import Combine
import SwiftUI
import Alamofire

final class GetDevicesViewModel: ObservableObject {
    @Published var devices: [GetDeviceData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @ObservedObject private var userSession = UserSession.shared
   // @ObservedObject private var merchantSession = MerchantSession.shared
    // MARK: - Fetch Linked Devices (Callback-based)
    func fetchUserDevices(clearMessages: Bool = true, showErrors: Bool = true) {
        isLoading = true

        if clearMessages {
            errorMessage = nil
            successMessage = nil
        }
            print("👤 Using USER repository for device fetch")
            UserDevicesRepository.shared.getUserDevices { [weak self] result in
                self?.handleDevicesResult(result, showErrors: showErrors)
        }
    }
    
    // MARK: - Fetch Linked Devices (Async/Await for .refreshable)
    @MainActor
    func fetchUserDevices() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        await withCheckedContinuation { continuation in

                print("👤 Using USER repository for async device fetch")
                UserDevicesRepository.shared.getUserDevices { [weak self] result in
                    self?.handleDevicesResult(result, showErrors: true)
                    continuation.resume()
            }
        }
    }
    
    // MARK: - Change Primary Device
    func changePrimaryDevice(to deviceId: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("🔄 Change primary device requested")
        print("   Device ID: \(deviceId)")
        
            print("👤 Using USER repository for change primary")
            UserDevicesRepository.shared.changePrimaryDevice(deviceId: deviceId) { [weak self] result in
                self?.handleChangePrimaryResult(result)

        }
    }
    
    // MARK: - Unlink This Device
    func unlinkThisDevice() {
        isLoading = true
        
        let currentDeviceId: String
            currentDeviceId = UserSession.shared.currentUserDeviceID
            print("👤 Using USER device ID: \(currentDeviceId)")
       
        
        guard !currentDeviceId.isEmpty else {
            self.errorMessage = "No device ID found."
            isLoading = false
            return
        }
        
            print("👤 Using USER repository for unlink this device")
            UserDevicesRepository.shared.unlinkThisDevice(deviceId: currentDeviceId) { [weak self] result in
                self?.handleUnlinkResult(result)
          //  }
        }
    }
    
    // MARK: - Unlink Other Device (by device ID)
    func unlinkOtherDevice(deviceId: String) {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        print("🔗 Unlink device requested: \(deviceId)")

            print("👤 Using USER repository for unlink other device")
            UserDevicesRepository.shared.unlinkThisDevice(deviceId: deviceId) { [weak self] result in
                self?.handleUnlinkResult(result)
           // }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func handleDevicesResult(_ result: Result<[GetDeviceData], APIError>, showErrors: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let devices):
                self.devices = devices
                self.errorMessage = nil
                print("✅ Loaded \(devices.count) devices successfully")

            case .failure(let error):
                print("❌ Fetch devices failed: \(error.localizedDescription)")
                
                if showErrors && self.successMessage == nil {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleChangePrimaryResult(_ result: Result<String, APIError>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.isLoading = false
                self.successMessage = message
                self.fetchUserDevices(clearMessages: false, showErrors: false)

                    print("✅ Updating user primary device status")
                    UserSession.shared.setThisDevicePrimary(false)
               // }

            case .failure(let error):
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                print("❌ Change primary device failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleUnlinkResult(_ result: Result<String, APIError>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let message):
                self.successMessage = message
                print("✅ Device unlinked successfully: \(message)")
                // Refresh the devices list after successful unlink
                self.fetchUserDevices(clearMessages: false, showErrors: false)
                
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("❌ Unlink device failed: \(error.localizedDescription)")
            }
        }
    }
}
