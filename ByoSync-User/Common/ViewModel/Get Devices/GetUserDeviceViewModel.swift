import Foundation
import Combine
import SwiftUI
import Alamofire

final class GetDevicesViewModel: ObservableObject {
    @Published var devices: [DeviceData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @ObservedObject private var userSession = UserSession.shared
   // @ObservedObject private var merchantSession = MerchantSession.shared
    
    // MARK: - Session Detection
//    private var isMerchantMode: Bool {
//        merchantSession.isLoggedIn
//    }
    
    // MARK: - Fetch Linked Devices (Callback-based)
    func fetchUserDevices(clearMessages: Bool = true, showErrors: Bool = true) {
        isLoading = true

        if clearMessages {
            errorMessage = nil
            successMessage = nil
        }

//        if isMerchantMode {
//            print("📱 Using MERCHANT repository for device fetch")
//            MerchantDevicesRepository.shared.getUserDevices { [weak self] result in
//                self?.handleDevicesResult(result, showErrors: showErrors)
//            }
//        } else {
            print("👤 Using USER repository for device fetch")
            UserDevicesRepository.shared.getUserDevices { [weak self] result in
                self?.handleDevicesResult(result, showErrors: showErrors)
          //  }
        }
    }
    
    // MARK: - Fetch Linked Devices (Async/Await for .refreshable)
    @MainActor
    func fetchUserDevices() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        await withCheckedContinuation { continuation in
//            if isMerchantMode {
//                print("📱 Using MERCHANT repository for async device fetch")
//                MerchantDevicesRepository.shared.getUserDevices { [weak self] result in
//                    self?.handleDevicesResult(result, showErrors: true)
//                    continuation.resume()
//                }
//            } else {
                print("👤 Using USER repository for async device fetch")
                UserDevicesRepository.shared.getUserDevices { [weak self] result in
                    self?.handleDevicesResult(result, showErrors: true)
                    continuation.resume()
              //  }
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
        
//        if isMerchantMode {
//            print("📱 Using MERCHANT repository for change primary")
//            MerchantDevicesRepository.shared.changePrimaryDevice(deviceId: deviceId) { [weak self] result in
//                self?.handleChangePrimaryResult(result)
//            }
//        } else {
            print("👤 Using USER repository for change primary")
            UserDevicesRepository.shared.changePrimaryDevice(deviceId: deviceId) { [weak self] result in
                self?.handleChangePrimaryResult(result)
           // }
        }
    }
    
    // MARK: - Unlink This Device
    func unlinkThisDevice() {
        isLoading = true
        
        let currentDeviceId: String
//        if isMerchantMode {
//            currentDeviceId = merchantSession.merchantDeviceId
//            print("📱 Using MERCHANT device ID: \(currentDeviceId)")
//        } else {
            currentDeviceId = UserSession.shared.currentUserDeviceID
            print("👤 Using USER device ID: \(currentDeviceId)")
       // }
        
        guard !currentDeviceId.isEmpty else {
            self.errorMessage = "No device ID found."
            isLoading = false
            return
        }
        
//        if isMerchantMode {
//            print("📱 Using MERCHANT repository for unlink this device")
//            MerchantDevicesRepository.shared.unlinkThisDevice(deviceId: currentDeviceId) { [weak self] result in
//                self?.handleUnlinkResult(result)
//            }
//        } else {
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
        
//        if isMerchantMode {
//            print("📱 Using MERCHANT repository for unlink other device")
//            MerchantDevicesRepository.shared.unlinkThisDevice(deviceId: deviceId) { [weak self] result in
//                self?.handleUnlinkResult(result)
//            }
//        } else {
            print("👤 Using USER repository for unlink other device")
            UserDevicesRepository.shared.unlinkThisDevice(deviceId: deviceId) { [weak self] result in
                self?.handleUnlinkResult(result)
           // }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func handleDevicesResult(_ result: Result<[DeviceData], APIError>, showErrors: Bool) {
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
                
                // Update the appropriate session
//                if self.isMerchantMode {
//                    print("✅ Updating merchant primary device status")
//                    MerchantSession.shared.saveMerchantDevicePrimaryStatus(false)
//                } else {
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
