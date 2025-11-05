import Foundation
import Alamofire

final class UserDevicesRepository {
    static let shared = UserDevicesRepository()
    private init() {}

    // MARK: - Get Linked Devices
    func getUserDevices(completion: @escaping (Result<[DeviceData], APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.getLinkedDevices
        let headers = getHeader.shared.getAuthHeaders()
        
        APIClient.shared.request(
            endpoint,
            method: .get,
            headers: headers
        ) { (result: Result<APIResponse<[DeviceData]>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false, let devices = response.data {
                    completion(.success(devices))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Change Primary Device
    func changePrimaryDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.changePrimaryDevice
        let headers = getHeader.shared.getAuthHeaders()
        let params: [String: Any] = ["deviceId": deviceId]

        print("🔄 Attempting to change primary device to: \(deviceId)")
        
        APIClient.shared.requestWithoutValidation(
            endpoint,
            method: .patch,
            parameters: params,
            headers: headers,
            skipValidation: true
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    completion(.success(response.message))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                print("❌ Change primary device failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Unlink Other Devices
    func unlinkOtherDevices(completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
        let headers = getHeader.shared.getAuthHeaders()
        let currentDeviceId = UserSession.shared.currentUserDeviceID
        
        guard !currentDeviceId.isEmpty else {
            completion(.failure(.custom("No device ID found.")))
            return
        }

        let params: [String: Any] = ["deviceId": currentDeviceId]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    completion(.success(response.message))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Unlink This Device (for non-primary devices)
    func unlinkThisDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
        let headers = getHeader.shared.getAuthHeaders()
        let params: [String: Any] = ["deviceId": deviceId]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: params,
            headers: headers
        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
            switch result {
            case .success(let response):
                if response.success ?? false {
                    completion(.success(response.message))
                } else {
                    completion(.failure(.custom(response.message)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}



//final class MerchantDevicesRepository {
//    static let shared = MerchantDevicesRepository()
//    private init() {}
//
//    // MARK: - Get Linked Devices
//    func getUserDevices(completion: @escaping (Result<[DeviceData], APIError>) -> Void) {
//        let endpoint = UserAPIEndpoint.UserDeviceManagement.getLinkedDevices
//        let headers = getHeader.shared.getAuthHeaders()
//        
//        print("🔍 Fetching merchant devices from: \(endpoint)")
//        
//        APIClient.shared.request(
//            endpoint,
//            method: .get,
//            headers: headers
//        ) { (result: Result<APIResponse<[DeviceData]>, APIError>) in
//            switch result {
//            case .success(let response):
//                print("✅ Merchant devices response received")
//                if response.success ?? false, let devices = response.data {
//                    print("✅ Successfully loaded \(devices.count) merchant devices")
//                    completion(.success(devices))
//                } else {
//                    print("❌ Server returned success=false: \(response.message ?? "No message")")
//                    completion(.failure(.custom(response.message)))
//                }
//            case .failure(let error):
//                print("❌ Failed to fetch merchant devices: \(error.localizedDescription)")
//                completion(.failure(error))
//            }
//        }
//    }
//
//    // MARK: - Change Primary Device
//    func changePrimaryDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
//        let endpoint = UserAPIEndpoint.UserDeviceManagement.changePrimaryDevice
//        let headers = getHeader.shared.getAuthHeaders()
//        let params: [String: Any] = ["deviceId": deviceId]
//
//        print("🔄 Attempting to change primary device to: \(deviceId)")
//        
//        APIClient.shared.requestWithoutValidation(
//            endpoint,
//            method: .patch,
//            parameters: params,
//            headers: headers,
//            skipValidation: true
//        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
//            switch result {
//            case .success(let response):
//                if response.success ?? false {
//                    completion(.success(response.message))
//                    MerchantSession.shared.saveMerchantDevicePrimaryStatus(false)
//                } else {
//                    completion(.failure(.custom(response.message)))
//                }
//            case .failure(let error):
//                print("❌ Change primary device failed: \(error.localizedDescription)")
//                completion(.failure(error))
//            }
//        }
//    }
//
//    // MARK: - Unlink Other Devices
//    func unlinkOtherDevices(completion: @escaping (Result<String, APIError>) -> Void) {
//        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
//        let headers = getHeader.shared.getAuthHeaders()
//        let currentDeviceId = MerchantSession.shared.merchantDeviceId
//        
//        guard !currentDeviceId.isEmpty else {
//            print("❌ No merchant device ID found")
//            completion(.failure(.custom("No device ID found.")))
//            return
//        }
//
//        let params: [String: Any] = ["deviceId": currentDeviceId]
//        
//        print("🔗 Attempting to unlink other merchant devices")
//        print("📍 Current device ID: \(currentDeviceId)")
//        
//        APIClient.shared.request(
//            endpoint,
//            method: .post,
//            parameters: params,
//            headers: headers
//        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
//            switch result {
//            case .success(let response):
//                if response.success ?? false {
//                    print("✅ Other devices unlinked successfully")
//                    completion(.success(response.message ?? "Devices unlinked"))
//                } else {
//                    print("❌ Server error: \(response.message ?? "Unknown error")")
//                    completion(.failure(.custom(response.message)))
//                }
//            case .failure(let error):
//                print("❌ Failed to unlink devices: \(error.localizedDescription)")
//                completion(.failure(error))
//            }
//        }
//    }
//
//    // MARK: - Unlink This Device (for non-primary devices)
//    func unlinkThisDevice(deviceId: String, completion: @escaping (Result<String, APIError>) -> Void) {
//        let endpoint = UserAPIEndpoint.UserDeviceManagement.unLinkOtherDevices
//        let headers = getHeader.shared.getAuthHeaders()
//        let params: [String: Any] = ["deviceId": deviceId]
//        
//        print("🔗 Attempting to unlink merchant device: \(deviceId)")
//        
//        APIClient.shared.request(
//            endpoint,
//            method: .post,
//            parameters: params,
//            headers: headers
//        ) { (result: Result<APIResponse<EmptyData>, APIError>) in
//            switch result {
//            case .success(let response):
//                if response.success ?? false {
//                    print("✅ Device unlinked successfully: \(deviceId)")
//                    completion(.success(response.message ?? "Device unlinked"))
//                } else {
//                    print("❌ Server error: \(response.message ?? "Unknown error")")
//                    completion(.failure(.custom(response.message)))
//                }
//            case .failure(let error):
//                print("❌ Failed to unlink device: \(error.localizedDescription)")
//                completion(.failure(error))
//            }
//        }
//    }
//}
