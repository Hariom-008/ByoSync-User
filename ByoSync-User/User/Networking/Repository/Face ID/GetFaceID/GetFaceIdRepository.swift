//
//  GetFaceId.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 10.12.2025.
//

import Foundation
import Alamofire

final class FaceIdFetchRepository {
    
    static let shared = FaceIdFetchRepository()
    
    private let hmacGenerator = HMACGenerator.self

    func getFaceIds(
        deviceKey: String,
        completion: @escaping (Result<GetFaceIdData, APIError>) -> Void
    ) {
        let deviceKeyHash = hmacGenerator.generateHMAC(jsonString: deviceKey)
        let headers: HTTPHeaders = getHeader.shared.getAuthHeaders()
        
        let body: [String: Any] = [
            "deviceKeyHash": deviceKeyHash
        ]
        
        print("📤 [FaceIdFetchRepository] getFaceIds -> URL: \(UserAPIEndpoint.FaceId.getFaceId)")
        print("📤 [FaceIdFetchRepository] Headers: \(headers)")
        print("📤 [FaceIdFetchRepository] Body: \(body)")
        
        APIClient.shared.request(
            UserAPIEndpoint.FaceId.getFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { (result: Result<GetFaceIdResponse, APIError>) in
            switch result {
            case .success(let response):
                print("✅ [FaceIdFetchRepository] StatusCode: \(response.statusCode) " +
                      "success: \(response.success) message: \(response.message)")
                
                let data = response.data
                print("✅ [FaceIdFetchRepository] Received salt: \(data.salt)")
                print("✅ [FaceIdFetchRepository] Received \(data.faceData.count) FaceId items")
                
                completion(.success(data))
                
            case .failure(let error):
                print("❌ [FaceIdFetchRepository] Failed to fetch faceId: \(error)")
                completion(.failure(error))
            }
        }
    }
}
