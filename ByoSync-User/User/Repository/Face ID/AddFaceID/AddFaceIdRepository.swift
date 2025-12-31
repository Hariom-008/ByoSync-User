//
//  AddFaceIdRepository.swift
//  ByoSync-User
//

import Foundation
import Alamofire

// MARK: - Request Body Object
struct AddFaceIdRequestBody: Codable {
    let helper: String
    let k2: String
    let token: String
    let iod : String
}

final class FaceIdRepository {
    
    static let shared = FaceIdRepository()
    private init() {}
    
    /// Upload multiple FaceId items (backend expects array)
    func addFaceIds(
        salt: String,
        records: [AddFaceIdRequestBody],
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let headers = getHeader.shared.getAuthHeaders()

        // Convert `[AddFaceIdRequestBody]` → `[[String: Any]]`
        let faceIdArray: [[String: Any]]
        do {
            let jsonData = try JSONEncoder().encode(records)
            faceIdArray = (try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]) ?? []
        } catch {
            completion(.failure(.custom("Encoding error: \(error.localizedDescription)")))
            return
        }

        let body: [String: Any] = [
            "salt": salt,
            "faceId": faceIdArray
        ]

        print("\n📤 [FaceIdRepository] addFaceIds → URL: \(UserAPIEndpoint.FaceId.addFaceId)")
        print("📤 Headers: \(headers)")
        print("📤 Body: \(body)\n")

        APIClient.shared.requestWithoutResponse(
            UserAPIEndpoint.FaceId.addFaceId,
            method: .post,
            parameters: body,
            headers: headers
        ) { result in
            switch result {
            case .success:
                print("✅ Successfully uploaded faceId list")
                completion(.success(()))
            case .failure(let error):
                print("❌ Failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Upload **one** record
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
