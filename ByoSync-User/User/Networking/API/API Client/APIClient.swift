import Foundation

enum APIConfig {
    static let baseURL = URL(string: "https://backendapi.byosync.in")!
    static let host = "backendapi.byosync.in"
}

// MARK: - APIClient (Singleton)
final class APIClient: NSObject {
    static let shared = APIClient()
    
    private var session: URLSession!
    private var pinnedCertificates: [SecCertificate] = []
    
    private override init() {
        super.init()
        
        // Load certificates from bundle
        loadPinnedCertificates()
        
        // Configure URLSession
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Create session with self as delegate for certificate pinning
        self.session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        
        print("🔐 Found \(pinnedCertificates.count) bundled certificates")
    }
    
    // MARK: - Load Certificates
    private func loadPinnedCertificates() {
         let cerPaths = Bundle.main.paths(forResourcesOfType: "cer", inDirectory: nil)
        if cerPaths.isEmpty{
            print("⚠️ No .cer files found in bundle")
            return
        }
        
        for cerPath in cerPaths {
            guard let cerData = try? Data(contentsOf: URL(fileURLWithPath: cerPath)),
                  let certificate = SecCertificateCreateWithData(nil, cerData as CFData) else {
                print("⚠️ Failed to load certificate at: \(cerPath)")
                continue
            }
            
            pinnedCertificates.append(certificate)
            print("🔐 Cert loaded: \(cerPath)")
        }
    }
    
    // MARK: - Generic Request Method (For responses that return data)
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }
        
        // Add JSON body if parameters exist
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: nil, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            print("📥 RAW API RESPONSE: \(endpoint)")
            print("📥 Status Code: \(httpResponse.statusCode)")
            
            guard let data = data else {
                print("❌ No Data")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
            
            // Check status code
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
                return
            }
            
            // Decode response
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
        }
        
        task.resume()
    }
    
    // MARK: - Request Without Response
    func requestWithoutResponse(
        _ endpoint: String,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }
        
        // Add JSON body if parameters exist
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: nil, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            print("📥 Status Code: \(httpResponse.statusCode)")
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
                return
            }
            
            completion(.success(()))
        }
        
        task.resume()
    }
    
    // MARK: - Custom Request with Raw Body
    func requestWithCustomBody(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<Void, APIError>) -> Void
    ) {
        // Safety check: only HTTPS
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            print("📥 Response Status Code: \(httpResponse.statusCode)")
            
            if let data = data,
               let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response Body: \(responseString)")
            }
            
            if let error = error {
                print("❌ Request Error: \(error)")
                let apiError = APIError.map(from: httpResponse.statusCode, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            if (200..<300).contains(httpResponse.statusCode) {
                print("✅ Request successful")
                completion(.success(()))
            } else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: data)
                completion(.failure(apiError))
            }
        }
        
        task.resume()
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
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add headers
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }
        
        // Add JSON body if parameters exist
        if let parameters = parameters {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                print("❌ JSON Encoding Error:", error.localizedDescription)
                completion(.failure(.custom("Failed to encode request parameters")))
                return
            }
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data else {
                if let error = error {
                    print("❌ Network Error:", error.localizedDescription)
                    let apiError = APIError.map(from: nil, error: error, data: nil)
                    completion(.failure(apiError))
                } else {
                    print("❌ No Data")
                    completion(.failure(.custom("No data received from server")))
                }
                return
            }
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? -1
            
            // Try to decode regardless of status code if skipValidation is true
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: data)
                
                // If skipValidation, return success even on error status codes
                if skipValidation || (200..<300).contains(statusCode) {
                    completion(.success(decoded))
                } else {
                    let apiError = APIError.map(from: statusCode, error: nil, data: data)
                    completion(.failure(apiError))
                }
            } catch {
                print("❌ Decoding error: \(error)")
                print("❌ Failed to decode type: \(T.self)")
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 Raw Error Body: \(jsonString)")
                }
                
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Download File
    func downloadFile(
        _ endpoint: String,
        method: HTTPMethod,
        headers: HTTPHeaders? = nil,
        completion: @escaping (Result<URL, APIError>) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            completion(.failure(.custom("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60
        
        // Add headers
        if let headers = headers {
            for header in headers {
                request.setValue(header.value, forHTTPHeaderField: header.name)
            }
        }
        
        let task = session.downloadTask(with: request) { tempURL, response, error in
            if let error = error {
                print("❌ Download Error:", error.localizedDescription)
                let apiError = APIError.map(from: nil, error: error, data: nil)
                completion(.failure(apiError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid Response")
                completion(.failure(.custom("Invalid response from server")))
                return
            }
            
            guard (200..<300).contains(httpResponse.statusCode) else {
                let apiError = APIError.map(from: httpResponse.statusCode, error: nil, data: nil)
                completion(.failure(apiError))
                return
            }
            
            guard let tempURL = tempURL else {
                print("❌ No File URL")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            // Move to permanent location
            let documentsURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsURL.appendingPathComponent(
                "transaction_report_\(Date().timeIntervalSince1970).pdf"
            )
            
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Move temp file to destination
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("✅ File downloaded to: \(destinationURL.path)")
                completion(.success(destinationURL))
            } catch {
                print("❌ File move error:", error.localizedDescription)
                completion(.failure(.custom("Failed to save downloaded file")))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Custom Request with Raw Body AND Response Decoding
    func requestWithCustomBodyAndResponse<T: Decodable>(
        _ urlRequest: URLRequest,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        assert(urlRequest.url?.scheme == "https", "All requests must use HTTPS")
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("📥 [APIClient] Status Code:", status)
            
            if let data = data,
               let raw = String(data: data, encoding: .utf8) {
                print("📥 [APIClient] Raw Response:\n\(raw)")
            }
            
            if let error = error {
                print("❌ [APIClient] Network Error:", error.localizedDescription)
                let apiError = APIError.map(from: status != -1 ? status : nil, error: error, data: data)
                completion(.failure(apiError))
                return
            }
            
            guard let data = data else {
                print("❌ [APIClient] No Data")
                completion(.failure(.custom("No data received from server")))
                return
            }
            
            // Try to decode
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try decoder.decode(T.self, from: data)
                print("✅ [APIClient] Successfully decoded \(T.self)")
                completion(.success(decoded))
            } catch {
                print("❌ [APIClient] JSON decode error:", error)
                
                // Try to decode backend error
                if let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
                    print("⚠️ Backend Error:", backendError.message ?? "Unknown")
                }
                
                completion(.failure(.decodingError(error.localizedDescription)))
            }
        }
        
        task.resume()
    }
}

// MARK: - URLSessionDelegate for Certificate Pinning
extension APIClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Only pin our specific host
        guard challenge.protectionSpace.host == APIConfig.host else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            print("❌ No server trust found")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Validate server trust
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)
        
        guard status == errSecSuccess else {
            print("❌ Server trust evaluation failed")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Get server certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        var serverCertificates: [SecCertificate] = []
        
        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                serverCertificates.append(certificate)
            }
        }
        
        // Check if any server certificate matches our pinned certificates
        var isPinned = false
        for serverCert in serverCertificates {
            let serverCertData = SecCertificateCopyData(serverCert) as Data
            
            for pinnedCert in pinnedCertificates {
                let pinnedCertData = SecCertificateCopyData(pinnedCert) as Data
                
                if serverCertData == pinnedCertData {
                    isPinned = true
                    print("✅ Certificate pinning successful")
                    break
                }
            }
            
            if isPinned { break }
        }
        
        if isPinned {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            print("❌ Certificate pinning failed - no matching certificate")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Supporting Types
typealias Parameters = [String: Any]

struct HTTPHeaders: ExpressibleByDictionaryLiteral {
    private var headers: [HTTPHeader]
    
    init(_ headers: [HTTPHeader] = []) {
        self.headers = headers
    }
    
    init(_ dictionary: [String: String]) {
        self.headers = dictionary.map { HTTPHeader(name: $0.key, value: $0.value) }
    }
    
    // ExpressibleByDictionaryLiteral conformance
    init(dictionaryLiteral elements: (String, String)...) {
        self.headers = elements.map { HTTPHeader(name: $0.0, value: $0.1) }
    }
    
    // Computed property for Alamofire compatibility
    var dictionary: [String: String] {
        var dict: [String: String] = [:]
        for header in headers {
            dict[header.name] = header.value
        }
        return dict
    }
    
    subscript(name: String) -> String? {
        get {
            headers.first(where: { $0.name.lowercased() == name.lowercased() })?.value
        }
        set {
            if let newValue = newValue {
                update(name: name, value: newValue)
            } else {
                remove(name: name)
            }
        }
    }
    
    mutating func add(name: String, value: String) {
        headers.append(HTTPHeader(name: name, value: value))
    }
    
    mutating func add(_ header: HTTPHeader) {
        headers.append(header)
    }
    
    mutating func update(name: String, value: String) {
        if let index = headers.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            headers[index] = HTTPHeader(name: name, value: value)
        } else {
            add(name: name, value: value)
        }
    }
    
    mutating func remove(name: String) {
        headers.removeAll(where: { $0.name.lowercased() == name.lowercased() })
    }
}

extension HTTPHeaders: Sequence {
    func makeIterator() -> IndexingIterator<[HTTPHeader]> {
        return headers.makeIterator()
    }
}

struct HTTPHeader {
    let name: String
    let value: String
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

private struct BackendError: Codable {
    let message: String?
    let error: String?
}
