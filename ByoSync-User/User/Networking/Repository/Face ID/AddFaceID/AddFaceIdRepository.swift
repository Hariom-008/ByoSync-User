//
//  AddFaceIdRepository.swift
//  ByoSync-User
//

import Foundation
import Alamofire

final class FaceIdRepository {
    
    static let shared = FaceIdRepository()
    private init() {}
    
    func addFaceIds(
        salt: String,
        records: [AddFaceIdRequestBody],
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let headers = getHeader.shared.getAuthHeaders()
        let userID = UserSession.shared.currentUserID

        let faceIdArray: [[String: Any]]
        do {
            let jsonData = try JSONEncoder().encode(records)
            faceIdArray = (try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]) ?? []
        } catch {
            completion(.failure(.custom("Encoding error: \(error.localizedDescription)")))
            return
        }

        let body: [String: Any] = [
            "userId": userID,
            "salt": salt,
            "faceId": faceIdArray
        ]

        #if DEBUG
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])

            print("\n📤 [FaceIdRepository] addFaceIds → URL: \(UserAPIEndpoint.FaceId.addFaceId)")
            print("📤 Headers: \(headers)")
            print("📦 Body bytes: \(data.count) (~\(String(format: "%.2f", Double(data.count)/1024.0)) KB)")

        } catch {
            print("❌ [FaceIdRepository] JSON print failed: \(error)\n")
        }
        #endif

        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.FaceId.addFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { result in
            switch result {
            case .success:
                #if DEBUG
                print("✅ Successfully uploaded faceId list")
                #endif
                completion(.success(()))
            case .failure(let error):
                #if DEBUG
                print("❌ Failed: \(error)")
                #endif
                completion(.failure(error))
            }
        }
    }
// For one-record Upload
    func addFaceId(
        salt: String,
        helper: String,
        k2: String,
        token: String,
        iod: String,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let item = AddFaceIdRequestBody(helper: helper, k2: k2, token: token,iod: iod)
        addFaceIds(salt: salt, records: [item], completion: completion)
    }
}
