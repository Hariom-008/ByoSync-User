//
//  CryptoManager.swift
//  ByoSync
//
//  Created by Hari's Mac on 24.10.2025.
//
import Foundation
import CryptoKit
import CommonCrypto
import SwiftUI

class CryptoManager {
    private let PASSWORD = "ByoSyncPayWithFace"
    private let SALT = "ByoSync"
    private let iterations: UInt32 = 65536
    private let keyLength = 32 // 256 bits for AES-256
    
    // MARK: - Generate Key using PBKDF2
    private func generateKey() -> Data? {
        guard let passwordData = PASSWORD.data(using: .utf8),
              let saltData = SALT.data(using: .utf8) else {
            return nil
        }
        
        var derivedKeyData = Data(repeating: 0, count: keyLength)
        let derivedCount = derivedKeyData.count
        
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            saltData.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.bytes,
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                    derivedCount
                )
            }
        }
        
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }
    
    // MARK: - Encrypt Function
    func encrypt(text: String) -> String? {
        guard let key = generateKey(),
              let textData = text.data(using: .utf8) else {
            return nil
        }
        
        // Generate random IV (16 bytes)
        var iv = Data(count: 16)
        let result = iv.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!)
        }
        
        guard result == errSecSuccess else { return nil }
        
        // Perform encryption
        let bufferSize = textData.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                textData.withUnsafeBytes { textBytes in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            textBytes.baseAddress,
                            textData.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else { return nil }
        
        buffer.removeSubrange(numBytesEncrypted..<buffer.count)
        
        // Return in format: IV:EncryptedData (both in hex)
        return iv.hexString + ":" + buffer.hexString
    }
    
    // MARK: - Decrypt Function
    func decrypt(encryptedData: String) -> String? {
        let components = encryptedData.split(separator: ":")
        guard components.count == 2,
              let ivData = Data(hexString: String(components[0])),
              let encryptedBytes = Data(hexString: String(components[1])),
              let key = generateKey() else {
            return nil
        }
        
        // Perform decryption
        let bufferSize = encryptedBytes.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0
        
        let cryptStatus = key.withUnsafeBytes { keyBytes in
            ivData.withUnsafeBytes { ivBytes in
                encryptedBytes.withUnsafeBytes { encryptedBytesPtr in
                    buffer.withUnsafeMutableBytes { bufferBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            encryptedBytesPtr.baseAddress,
                            encryptedBytes.count,
                            bufferBytes.baseAddress,
                            bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else { return nil }
        
        buffer.removeSubrange(numBytesDecrypted..<buffer.count)
        
        return String(data: buffer, encoding: .utf8)
    }
}

// MARK: - Data Extension for Hex Conversion
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        
        for i in 0..<length {
            let start = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let end = hexString.index(start, offsetBy: 2)
            let bytes = hexString[start..<end]
            
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        
        self = data
    }
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}



// MARK: - SwiftUI View Example
struct EncryptDecryptTestView: View {
    @State private var inputText = "Deepak Yadav"
    @State private var encryptedText = ""
    @State private var decryptedText = ""
    
    // For decrypting pre-encrypted values
    @State private var pastedEncryptedText = ""
    @State private var pastedDecryptedText = ""
    
    let cryptoManager = CryptoManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("AES-256 Encryption Demo")
                    .font(.title)
                    .padding()
                
                // MARK: - Encryption Section
                VStack(spacing: 15) {
                    Text("Encrypt Text")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Enter text to encrypt", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Encrypt") {
                        if let encrypted = cryptoManager.encrypt(text: inputText) {
                            encryptedText = encrypted
                            print("Encrypted: \(encrypted)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if !encryptedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Encrypted:")
                                .font(.headline)
                            Text(encryptedText)
                                .font(.caption)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Decrypt This") {
                            if let decrypted = cryptoManager.decrypt(encryptedData: encryptedText) {
                                decryptedText = decrypted
                                print("Decrypted: \(decrypted)")
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if !decryptedText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Decrypted:")
                                    .font(.headline)
                                Text(decryptedText)
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                
                Divider()
                    .padding(.vertical)
                
                // MARK: - Decrypt Pre-encrypted Values Section
                VStack(spacing: 15) {
                    Text("Decrypt Encrypted Value")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Paste your encrypted text (IV:EncryptedData format)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextEditor(text: $pastedEncryptedText)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .font(.caption)
                    
                    Button("Decrypt Pasted Value") {
                        if !pastedEncryptedText.isEmpty {
                            if let decrypted = cryptoManager.decrypt(encryptedData: pastedEncryptedText) {
                                pastedDecryptedText = decrypted
                                print("Decrypted pasted value: \(decrypted)")
                            } else {
                                pastedDecryptedText = "❌ Decryption failed. Check format."
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(pastedEncryptedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    if !pastedDecryptedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Result:")
                                .font(.headline)
                            Text(pastedDecryptedText)
                                .foregroundColor(pastedDecryptedText.contains("❌") ? .red : .green)
                                .font(.title3)
                                .padding()
                                .background(pastedDecryptedText.contains("❌") ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button("Clear") {
                            pastedEncryptedText = ""
                            pastedDecryptedText = ""
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
}
