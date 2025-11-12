//
//  LogRepository.swift
//  ByoSync
//

import Foundation
import Alamofire

protocol LogRepositoryProtocol: Sendable {
    func sendLogs(_ logs: [BackendLogEntry], completion: @escaping @Sendable (Result<LogCreateResponse, APIError>) -> Void)
}

final class LogRepository: LogRepositoryProtocol {
    
    func sendLogs(_ logs: [BackendLogEntry], completion: @escaping @Sendable (Result<LogCreateResponse, APIError>) -> Void) {
        guard !logs.isEmpty else {
            completion(.failure(.custom("No logs to send")))
            return
        }
        
        print("📤 [LOG-REPO] Sending \(logs.count) logs individually to backend")
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        let group = DispatchGroup()
        var successCount = 0
        var lastError: APIError?
        
        // Send each log individually
        for (index, log) in logs.enumerated() {
            group.enter()
            
            let parameters: Parameters = [
                "type": log.type,
                "form": log.form,
                "message": log.message,
                "timeTaken": log.timeTaken,
                "user": log.user
            ]
            
            AF.request(
                LogEndpoint.createLogs,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: headers
            )
            .validate()
            .responseData { response in
                defer { group.leave() }
                
                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        let logResponse = try decoder.decode(LogCreateResponse.self, from: data)
                        successCount += 1
                        print("✅ [LOG-REPO] Log \(index + 1)/\(logs.count) sent: \(logResponse.message)")
                    } catch {
                        print("❌ [LOG-REPO] Log \(index + 1) decode error: \(error)")
                        lastError = APIError.decodingError("Failed to decode: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    print("❌ [LOG-REPO] Log \(index + 1) failed: \(error.localizedDescription)")
                    lastError = APIError.map(
                        from: response.response?.statusCode,
                        error: error,
                        data: response.data
                    )
                }
            }
        }
        
        // Wait for all requests to complete
        group.notify(queue: .global()) {
            if successCount == logs.count {
                print("✅ [LOG-REPO] All \(logs.count) logs sent successfully")
                completion(.success(LogCreateResponse(
                    success: true,
                    message: "Successfully sent \(successCount) logs",
                    statusCode: 200
                )))
            } else if successCount > 0 {
                print("⚠️ [LOG-REPO] Partially sent: \(successCount)/\(logs.count)")
                completion(.success(LogCreateResponse(
                    success: true,
                    message: "Partially sent: \(successCount)/\(logs.count) logs",
                    statusCode: 206
                )))
            } else {
                print("❌ [LOG-REPO] Failed to send all logs")
                completion(.failure(lastError ?? .custom("All log requests failed")))
            }
        }
    }
}
