import Alamofire
import Foundation

enum APIConfig{
    static let baseURL = URL(string: "https://backendapi.byosync.in")!
    static let host = "backendapi.byosync.in"
}

// MARK: - APIClient (Singleton)
final class APIClient {
    static let shared = APIClient()
    
    private let session: Session
    
    private init() {
        // 1. URLSession configuration
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        // 2. TLS / Server trust: certificate pinning
        // PinnedCertificatesTrustEvaluator() by default loads all .cer in main bundle.
        // We map it to the exact backend host.
        let evaluators: [String: ServerTrustEvaluating] = [
            APIConfig.host: PinnedCertificatesTrustEvaluator(
                acceptSelfSignedCertificates: false,
                performDefaultValidation: true,
                validateHost: true
            )
        ]
        
        let serverTrustManager = ServerTrustManager(evaluators: evaluators)
        
        // 3. Create Alamofire Session with trust manager
        self.session = Session(
            configuration: configuration,
            serverTrustManager: serverTrustManager
        )
    }
    
    // MARK: - Generic Request Method (For responses that return data)
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let certs = Bundle.main.af.certificates
        print("🔐 Found \(certs.count) bundled certificates")
        for c in certs {
            print("🔐 Cert:", c)
        }

        let requestHeaders = headers ?? HTTPHeaders()
        
        // Build URL relative to base (recommended)
        let urlString = endpoint

        
        session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .responseData { response in
            switch response.result {
            case .success(let data):
                // ADD THIS BLOCK to see raw JSON
                   print("═══════════════════════════════════════")
                   print("📥 RAW API RESPONSE:\(urlString)")
                   print("═══════════════════════════════════════")
                   if let jsonString = String(data: data, encoding: .utf8) {
                       print(jsonString)
                   }
                   print("═══════════════════════════════════════")
                
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    completion(.success(decodedResponse))
                } catch {
                    print("❌ JSON DECODE ERROR:", error)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📦 RAW RESPONSE:\n\(jsonString)")
                    }
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
                
            case .failure(let afError):
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: afError,
                    data: response.data
                )
                #if DEBUG
                print("Alamofire Error: \(afError)")
                #endif
                completion(.failure(apiError))
            }
        }
    }
    
    // MARK: - Request Without Response
    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint   // endpoint is a full absolute URL

        
        session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        .validate(statusCode: 200..<300)
        .response { response in
            if let error = response.error {
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: error,
                    data: response.data
                )
                completion(.failure(apiError))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Custom Request with Raw Body
    func requestWithCustomBody(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        // Safety check: only HTTPS
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .response { response in
                print("📥 Response Status Code: \(response.response?.statusCode ?? -1)")
                
                if let data = response.data,
                   let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Response Body: \(responseString)")
                }
                
                if let error = response.error {
                    print("❌ Request Error: \(error)")
                    let apiError = APIError.map(
                        from: response.response?.statusCode,
                        error: error,
                        data: response.data
                    )
                    completion(.failure(apiError))
                } else if let statusCode = response.response?.statusCode,
                          (200..<300).contains(statusCode) {
                    print("✅ Request successful")
                    completion(.success(()))
                } else {
                    completion(.failure(.unknown))
                }
            }
    }
    
    // MARK: - Request Without Validation
    func requestWithoutValidation<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        skipValidation: Bool = false,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint   // endpoint is a full absolute URL

        
        var req = session.request(
            urlString,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
        
        if !skipValidation {
            req = req.validate(statusCode: 200..<300)
        }
        
        req.responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    print("❌ Decoding error: \(error)")
                    print("❌ Failed to decode type: \(T.self)")
                    completion(.failure(.decodingError(error.localizedDescription)))
                }
                
            case .failure(let afError):
                if skipValidation, let data = response.data {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📥 Raw Error Body: \(jsonString)")
                    }
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    if let decoded = try? decoder.decode(T.self, from: data) {
                        completion(.success(decoded))
                        return
                    }
                }
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: afError,
                    data: response.data
                )
                completion(.failure(apiError))
            }
        }
    }
    
    // MARK: - Download File
    func downloadFile(
        _ endpoint: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        let requestHeaders = headers ?? HTTPHeaders()
        let urlString = endpoint
        
        let destination: DownloadRequest.Destination = { _, _ in
            let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent(
                "transaction_report_\(Date().timeIntervalSince1970).pdf"
            )
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        session.download(
            urlString,
            method: method,
            headers: requestHeaders,
            to: destination
        )
        .validate(statusCode: 200..<300)
        .response { response in
            if let error = response.error {
                let apiError = APIError.map(
                    from: response.response?.statusCode,
                    error: error,
                    data: nil
                )
                completion(.failure(apiError))
            } else if let fileURL = response.fileURL {
                completion(.success(fileURL))
            } else {
                completion(.failure(.unknown))
            }
        }
    }
    
    // MARK: - Custom Request with Raw Body AND Response Decoding
    func requestWithCustomBodyAndResponse<T: Decodable>(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        session.request(urlRequest)
            .responseData { response in
                let status = response.response?.statusCode ?? -1
                print("📥 [APIClient] Status Code:", status)
                
                if let data = response.data,
                   let raw = String(data: data, encoding: .utf8) {
                    print("📥 [APIClient] Raw Response:\n\(raw)")
                }
                
                switch response.result {
                case .success(let data):
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let decoded = try decoder.decode(T.self, from: data)
                        print("✅ [APIClient] Successfully decoded \(T.self)")
                        completion(.success(decoded))
                    } catch {
                        print("❌ [APIClient] JSON decode error:", error)
                        completion(.failure(.decodingError(error.localizedDescription)))
                    }
                    
                case .failure(let afError):
                    print("❌ [APIClient] Alamofire Error:", afError)
                    if let data = response.data,
                       let raw = String(data: data, encoding: .utf8) {
                        print("📦 [APIClient] Error Body:\n\(raw)")
                    }
                    
                    if let data = response.data,
                       let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
                        print("⚠️ Backend Error:", backendError.message ?? "Unknown")
                    }
                    
                    let apiError = APIError.map(
                        from: response.response?.statusCode,
                        error: afError,
                        data: response.data
                    )
                    completion(.failure(apiError))
                }
            }
    }
}

private struct BackendError: Codable {
    let message: String?
    let error: String?
}
