import Foundation
import os.log

final class ByoSyncLogger {
    static let shared = ByoSyncLogger()
    
    // MARK: - Log Categories (OSLog subsystems)
    private let securityLog = OSLog(subsystem: "com.byosync.security", category: "security")
    private let auditLog = OSLog(subsystem: "com.byosync.audit", category: "audit")
    private let complianceLog = OSLog(subsystem: "com.byosync.compliance", category: "dpdp_compliance")
    private let performanceLog = OSLog(subsystem: "com.byosync.performance", category: "performance")
    private let transactionLog = OSLog(subsystem: "com.byosync.transaction", category: "upi_transactions")
    private let networkLog = OSLog(subsystem: "com.byosync.network", category: "api_network")
    
    private init() {}
    
    // MARK: - 1. USER AUTHENTICATION & REGISTRATION LOGS
    
    /// Log user registration start
    func logUserRegistrationStarted(sessionId: String, registrationMethod: String){
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] User registration started - SessionID: %{public}@, Method: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               registrationMethod,
               timestamp)
        
        os_log("[COMPLIANCE] Registration initiated - SessionID: %{public}@, ConsentNoticeProvided: true, Purpose: payment_service_registration",
               log: complianceLog,
               type: .default,
               sessionId)
    }
    
    /// Log user registration completion
    func logUserRegistrationCompleted(sessionId: String, userId: String, kycStatus: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] User registration completed - SessionID: %{public}@, UserID: %{private}@, KYCStatus: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedUserId,
               kycStatus,
               timestamp)
        
        os_log("[COMPLIANCE] User onboarded - SessionID: %{public}@, ConsentObtained: true, DataLocality: India, PurposeSpecified: true",
               log: complianceLog,
               type: .default,
               sessionId)
    }
    
    /// Log user login attempt
    func logLoginAttempt(sessionId: String, userId: String?, authMethod: String, success: Bool) {
        let maskedUserId = maskPII(userId ?? "unknown")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Login attempt - SessionID: %{public}@, UserID: %{private}@, AuthMethod: %{public}@, Success: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: success ? .info : .error,
               sessionId,
               maskedUserId,
               authMethod,
               success ? "YES" : "NO",
               timestamp)
        
        if !success {
            os_log("[AUDIT] Failed authentication - SessionID: %{public}@, AuthMethod: %{public}@, RequiresInvestigation: evaluate",
                   log: auditLog,
                   type: .error,
                   sessionId,
                   authMethod)
        }
    }
    
    /// Log user logout
    func logUserLogout(sessionId: String, userId: String, duration: TimeInterval) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] User logout - SessionID: %{public}@, UserID: %{private}@, SessionDuration: %.2fs, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               maskedUserId,
               duration,
               timestamp)
    }
    
    // MARK: - 2. BIOMETRIC DATA PROCESSING LOGS
    
    /// Log biometric enrollment start
    func logBiometricEnrollmentStarted(sessionId: String, userId: String, biometricType: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] Biometric enrollment started - SessionID: %{public}@, UserID: %{private}@, BiometricType: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedUserId,
               biometricType,
               timestamp)
        
        os_log("[COMPLIANCE] Biometric data collection - SessionID: %{public}@, ConsentVerified: true, Purpose: payment_authentication, DataType: %{public}@, StorageLocation: India",
               log: complianceLog,
               type: .default,
               sessionId,
               biometricType)
    }
    
    /// Log biometric verification attempt
    func logBiometricVerification(sessionId: String, userId: String, biometricType: String, success: Bool, quality: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] Biometric verification - SessionID: %{public}@, UserID: %{private}@, BiometricType: %{public}@, Success: %{public}@, Quality: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedUserId,
               biometricType,
               success ? "YES" : "NO",
               quality,
               timestamp)
        
        os_log("[SECURITY] Auth verification result - SessionID: %{public}@, Method: biometric, Result: %{public}@",
               log: securityLog,
               type: success ? .info : .error,
               sessionId,
               success ? "success" : "failed")
    }
    
    /// Log camera permission events
    func logCameraPermission(sessionId: String, userId: String?, granted: Bool, purpose: String) {
        let maskedUserId = maskPII(userId ?? "unknown")
        
        os_log("[COMPLIANCE] Camera permission - SessionID: %{public}@, UserID: %{private}@, Granted: %{public}@, Purpose: %{public}@, ConsentType: camera_access",
               log: complianceLog,
               type: .default,
               sessionId,
               maskedUserId,
               granted ? "YES" : "NO",
               purpose)
    }
    
    
    // MARK: - 3. PAYMENT & TRANSACTION LOGS
    
    /// Log payment initiation
    func logPaymentInitiated(sessionId: String, transactionId: String, userId: String, amount: Decimal, merchantId: String?) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId)
        let maskedMerchant = maskPII(merchantId ?? "unknown")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[TRANSACTION] Payment initiated - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, Amount: MASKED, MerchantID: %{private}@, Timestamp: %{public}@",
               log: transactionLog,
               type: .info,
               sessionId,
               maskedTxnId,
               maskedUserId,
               maskedMerchant,
               timestamp)
        
        os_log("[AUDIT] UPI transaction start - SessionID: %{public}@, TxnID: %{private}@, PaymentMethod: face_auth_upi",
               log: auditLog,
               type: .default,
               sessionId,
               maskedTxnId)
        
        os_log("[COMPLIANCE] Payment processing - SessionID: %{public}@, TxnID: %{private}@, ConsentVerified: true, DataLocality: India, NPCICompliance: enabled",
               log: complianceLog,
               type: .default,
               sessionId,
               maskedTxnId)
    }
    
    /// Log payment completion
    func logPaymentCompleted(sessionId: String, transactionId: String, userId: String, status: String, processingTime: TimeInterval) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[TRANSACTION] Payment completed - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, Status: %{public}@, ProcessingTime: %.2fs, Timestamp: %{public}@",
               log: transactionLog,
               type: status == "success" ? .info : .error,
               sessionId,
               maskedTxnId,
               maskedUserId,
               status,
               processingTime,
               timestamp)
        
        os_log("[AUDIT] UPI transaction complete - SessionID: %{public}@, TxnID: %{private}@, FinalStatus: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedTxnId,
               status)
    }
    
    /// Log payment failure
    func logPaymentFailed(sessionId: String, transactionId: String, userId: String, reason: String, errorCode: String?) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[TRANSACTION] Payment failed - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, Reason: %{public}@, ErrorCode: %{public}@, Timestamp: %{public}@",
               log: transactionLog,
               type: .error,
               sessionId,
               maskedTxnId,
               maskedUserId,
               reason,
               errorCode ?? "none",
               timestamp)
        
        os_log("[SECURITY] Transaction failure event - SessionID: %{public}@, RequiresReview: %{public}@",
               log: securityLog,
               type: .error,
               sessionId,
               reason.contains("fraud") || reason.contains("security") ? "YES" : "NO")
    }
    
    
    /// Log API request
    func logAPIRequest(sessionId: String, endpoint: String, method: String, requestId: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[NETWORK] API request - SessionID: %{public}@, Endpoint: %{public}@, Method: %{public}@, RequestID: %{public}@, Timestamp: %{public}@",
               log: networkLog,
               type: .debug,
               sessionId,
               endpoint,
               method,
               requestId,
               timestamp)
    }
    
    /// Log API response
    func logAPIResponse(sessionId: String, endpoint: String, statusCode: Int, responseTime: TimeInterval, requestId: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[NETWORK] API response - SessionID: %{public}@, Endpoint: %{public}@, StatusCode: %{public}d, ResponseTime: %.3fs, RequestID: %{public}@, Timestamp: %{public}@",
               log: networkLog,
               type: statusCode >= 200 && statusCode < 300 ? .debug : .error,
               sessionId,
               endpoint,
               statusCode,
               responseTime,
               requestId,
               timestamp)
    }
    
    /// Log API error
    func logAPIError(sessionId: String, endpoint: String, error: Error, requestId: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[NETWORK] API error - SessionID: %{public}@, Endpoint: %{public}@, Error: %{public}@, RequestID: %{public}@, Timestamp: %{public}@",
               log: networkLog,
               type: .error,
               sessionId,
               endpoint,
               error.localizedDescription,
               requestId,
               timestamp)
        
        os_log("[SECURITY] Network error detected - SessionID: %{public}@, RequiresInvestigation: %{public}@",
               log: securityLog,
               type: .error,
               sessionId,
               error.localizedDescription.contains("unauthorized") || error.localizedDescription.contains("403") ? "YES" : "NO")
    }
    
    // MARK: - 5. CONSENT & DATA PROTECTION LOGS
    
    /// Log consent provided
    func logConsentProvided(sessionId: String, userId: String, consentType: String, purpose: String, scope: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[COMPLIANCE] Consent provided - SessionID: %{public}@, UserID: %{private}@, ConsentType: %{public}@, Purpose: %{public}@, Scope: %{public}@, Timestamp: %{public}@",
               log: complianceLog,
               type: .info,
               sessionId,
               maskedUserId,
               consentType,
               purpose,
               scope,
               timestamp)
        
        os_log("[AUDIT] Consent recorded - SessionID: %{public}@, ConsentType: %{public}@, Informed: true, Specific: true, Unconditional: true, FreelyGiven: true",
               log: auditLog,
               type: .default,
               sessionId,
               consentType)
    }
    
    /// Log data access by user (exercising rights)
    func logDataAccessRequest(sessionId: String, userId: String, requestType: String, dataCategory: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[COMPLIANCE] Data access request - SessionID: %{public}@, UserID: %{private}@, RequestType: %{public}@, DataCategory: %{public}@, Timestamp: %{public}@",
               log: complianceLog,
               type: .info,
               sessionId,
               maskedUserId,
               requestType,
               dataCategory,
               timestamp)
        
        os_log("[AUDIT] DPDP rights exercise - SessionID: %{public}@, RightType: %{public}@, ProcessingStatus: initiated",
               log: auditLog,
               type: .default,
               sessionId,
               requestType)
    }
    
    /// Log data deletion
    func logDataDeletion(sessionId: String, userId: String?, dataType: String, reason: String, deletionMethod: String) {
        let maskedUserId = maskPII(userId ?? "system")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[COMPLIANCE] Data deletion - SessionID: %{public}@, UserID: %{private}@, DataType: %{public}@, Reason: %{public}@, Method: %{public}@, Timestamp: %{public}@",
               log: complianceLog,
               type: .info,
               sessionId,
               maskedUserId,
               dataType,
               reason,
               deletionMethod,
               timestamp)
        
        os_log("[AUDIT] Data erasure completed - SessionID: %{public}@, DataCategory: %{public}@, Irreversible: true, VerificationRequired: true",
               log: auditLog,
               type: .default,
               sessionId,
               dataType)
    }
    
    /// Log data correction request
    func logDataCorrection(sessionId: String, userId: String, fieldName: String, oldValue: String?, newValue: String?) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Never log actual values, just metadata
        os_log("[COMPLIANCE] Data correction - SessionID: %{public}@, UserID: %{private}@, Field: %{public}@, ValuesUpdated: YES, Timestamp: %{public}@",
               log: complianceLog,
               type: .info,
               sessionId,
               maskedUserId,
               fieldName,
               timestamp)
    }
    
    /// Log unauthorized access attempt
    func logUnauthorizedAccess(sessionId: String, userId: String?, resource: String, ipAddress: String?, deviceId: String?) {
        let maskedUserId = maskPII(userId ?? "unknown")
        let maskedIP = maskPII(ipAddress ?? "unknown")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Unauthorized access - SessionID: %{public}@, UserID: %{private}@, Resource: %{public}@, IP: %{private}@, DeviceID: %{private}@, Timestamp: %{public}@",
               log: securityLog,
               type: .error,
               sessionId,
               maskedUserId,
               resource,
               maskedIP,
               deviceId ?? "unknown",
               timestamp)
        
        os_log("[AUDIT] Access violation detected - SessionID: %{public}@, RequiresImmediateAction: YES",
               log: auditLog,
               type: .fault,
               sessionId)
    }
    
    /// Log suspicious activity
    func logSuspiciousActivity(sessionId: String, userId: String, activityType: String, riskScore: Int, details: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Suspicious activity - SessionID: %{public}@, UserID: %{private}@, ActivityType: %{public}@, RiskScore: %{public}d, Details: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: riskScore > 70 ? .error : .default,
               sessionId,
               maskedUserId,
               activityType,
               riskScore,
               details,
               timestamp)
    }
    
    /// Log fraud detection event
    func logFraudDetection(sessionId: String, transactionId: String?, userId: String, fraudType: String, confidence: Double, action: String) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId ?? "unknown")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Fraud detected - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, FraudType: %{public}@, Confidence: %.2f%%, Action: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .fault,
               sessionId,
               maskedTxnId,
               maskedUserId,
               fraudType,
               confidence * 100,
               action,
               timestamp)
        
        os_log("[COMPLIANCE] Fraud prevention action - SessionID: %{public}@, Action: %{public}@, UserNotified: pending",
               log: complianceLog,
               type: .error,
               sessionId,
               action)
    }
    
    // MARK: - 8. WALLET & BANK ACCOUNT LOGS
    
    /// Log wallet creation
    func logWalletCreated(sessionId: String, userId: String, walletId: String, walletType: String) {
        let maskedUserId = maskPII(userId)
        let maskedWalletId = maskPII(walletId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] Wallet created - SessionID: %{public}@, UserID: %{private}@, WalletID: %{private}@, Type: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedUserId,
               maskedWalletId,
               walletType,
               timestamp)
    }
    
    /// Log wallet balance check
    func logWalletBalanceAccessed(sessionId: String, userId: String, walletId: String) {
        let maskedUserId = maskPII(userId)
        let maskedWalletId = maskPII(walletId)
        
        os_log("[AUDIT] Wallet balance accessed - SessionID: %{public}@, UserID: %{private}@, WalletID: %{private}@",
               log: auditLog,
               type: .debug,
               sessionId,
               maskedUserId,
               maskedWalletId)
    }
    
    // MARK: - 9. DEVICE & SESSION MANAGEMENT LOGS
    
    /// Log device registration
    func logDeviceRegistered(sessionId: String, userId: String, deviceId: String, deviceType: String, osVersion: String) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Device registered - SessionID: %{public}@, UserID: %{private}@, DeviceID: %{private}@, DeviceType: %{public}@, OS: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               maskedUserId,
               deviceId,
               deviceType,
               osVersion,
               timestamp)
    }
    
    /// Log device change/new device login
    func logNewDeviceLogin(sessionId: String, userId: String, deviceId: String, verified: Bool) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] New device login - SessionID: %{public}@, UserID: %{private}@, DeviceID: %{private}@, Verified: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: verified ? .info : .error,
               sessionId,
               maskedUserId,
               deviceId,
               verified ? "YES" : "NO",
               timestamp)
        
        if !verified {
            os_log("[AUDIT] Suspicious device login - SessionID: %{public}@, RequiresVerification: YES",
                   log: auditLog,
                   type: .error,
                   sessionId)
        }
    }
    
    /// Log performance metrics
    func logPerformanceMetrics(sessionId: String, screenName: String, loadTime: TimeInterval, memoryUsage: Double, cpuUsage: Double) {
        os_log("[PERFORMANCE] Metrics - SessionID: %{public}@, Screen: %{public}@, LoadTime: %.2fs, MemoryMB: %.2f, CPU: %.1f%%",
               log: performanceLog,
               type: .debug,
               sessionId,
               screenName,
               loadTime,
               memoryUsage,
               cpuUsage)
    }
    
    /// Log app crash or critical error
    func logCriticalError(sessionId: String, errorType: String, errorMessage: String, stackTrace: String?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Critical error - SessionID: %{public}@, ErrorType: %{public}@, Message: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .fault,
               sessionId,
               errorType,
               errorMessage,
               timestamp)
        
        os_log("[COMPLIANCE] System failure - SessionID: %{public}@, RequiresIncidentReport: YES, UserImpact: evaluate",
               log: complianceLog,
               type: .fault,
               sessionId)
    }
    
    /// Log slow operation/timeout
    func logSlowOperation(sessionId: String, operation: String, duration: TimeInterval, threshold: TimeInterval) {
        os_log("[PERFORMANCE] Slow operation - SessionID: %{public}@, Operation: %{public}@, Duration: %.2fs, Threshold: %.2fs",
               log: performanceLog,
               type: .info,
               sessionId,
               operation,
               duration,
               threshold)
    }
    
    // MARK: - 11. NOTIFICATION & COMMUNICATION LOGS
    
    /// Log notification sent
    func logNotificationSent(sessionId: String, userId: String, notificationType: String, channel: String, success: Bool) {
        let maskedUserId = maskPII(userId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] Notification sent - SessionID: %{public}@, UserID: %{private}@, Type: %{public}@, Channel: %{public}@, Success: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedUserId,
               notificationType,
               channel,
               success ? "YES" : "NO",
               timestamp)
    }
    
    /// Log SMS/OTP sent
    func logOTPSent(sessionId: String, userId: String?, phoneNumber: String, purpose: String, provider: String) {
        let maskedUserId = maskPII(userId ?? "unknown")
        let maskedPhone = maskPhoneNumber(phoneNumber)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] OTP sent - SessionID: %{public}@, UserID: %{private}@, Phone: %{private}@, Purpose: %{public}@, Provider: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               maskedUserId,
               maskedPhone,
               purpose,
               provider,
               timestamp)
    }
    
    /// Log OTP verification
    func logOTPVerification(sessionId: String, userId: String?, success: Bool, attempts: Int) {
        let maskedUserId = maskPII(userId ?? "unknown")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] OTP verification - SessionID: %{public}@, UserID: %{private}@, Success: %{public}@, Attempts: %{public}d, Timestamp: %{public}@",
               log: securityLog,
               type: success ? .info : .error,
               sessionId,
               maskedUserId,
               success ? "YES" : "NO",
               attempts,
               timestamp)
        
        if attempts > 3 {
            os_log("[AUDIT] Multiple OTP failures - SessionID: %{public}@, RequiresInvestigation: YES",
                   log: auditLog,
                   type: .error,
                   sessionId)
        }
    }
    
    // MARK: - 12. MERCHANT & BUSINESS LOGS
    
    /// Log merchant transaction
    func logMerchantTransaction(sessionId: String, transactionId: String, userId: String, merchantId: String, merchantName: String, category: String) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId)
        let maskedMerchantId = maskPII(merchantId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[TRANSACTION] Merchant payment - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, MerchantID: %{private}@, MerchantName: %{public}@, Category: %{public}@, Timestamp: %{public}@",
               log: transactionLog,
               type: .info,
               sessionId,
               maskedTxnId,
               maskedUserId,
               maskedMerchantId,
               merchantName,
               category,
               timestamp)
    }
    
    /// Log cashback/rewards earned
    func logCashbackEarned(sessionId: String, transactionId: String, userId: String, amount: Decimal, reason: String) {
        let maskedUserId = maskPII(userId)
        let maskedTxnId = maskPII(transactionId)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[AUDIT] Cashback earned - SessionID: %{public}@, TxnID: %{private}@, UserID: %{private}@, Amount: MASKED, Reason: %{public}@, Timestamp: %{public}@",
               log: auditLog,
               type: .info,
               sessionId,
               maskedTxnId,
               maskedUserId,
               reason,
               timestamp)
    }

    // MARK: - 14. ENCRYPTION & SECURITY OPERATIONS LOGS
    
    /// Log key rotation
    func logKeyRotation(sessionId: String, keyType: String, rotationReason: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        os_log("[SECURITY] Key rotation - SessionID: %{public}@, KeyType: %{public}@, Reason: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               keyType,
               rotationReason,
               timestamp)
        
        os_log("[AUDIT] Cryptographic key rotated - SessionID: %{public}@, OldKeyInvalidated: true, NewKeyActive: true",
               log: auditLog,
               type: .default,
               sessionId)
    }
    
    /// Log certificate validation
    func logCertificateValidation(sessionId: String, certificateType: String, domain: String, valid: Bool, expiryDate: Date?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let expiryString = expiryDate.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
        
        os_log("[SECURITY] Certificate validation - SessionID: %{public}@, Type: %{public}@, Domain: %{public}@, Valid: %{public}@, Expiry: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: valid ? .info : .error,
               sessionId,
               certificateType,
               domain,
               valid ? "YES" : "NO",
               expiryString,
               timestamp)
    }
    
    
    /// Log screen view (for analytics, not PII)
    func logScreenView(sessionId: String, screenName: String, duration: TimeInterval?, source: String?) {
        os_log("[PERFORMANCE] Screen view - SessionID: %{public}@, Screen: %{public}@, Duration: %.2fs, Source: %{public}@",
               log: performanceLog,
               type: .debug,
               sessionId,
               screenName,
               duration ?? 0,
               source ?? "direct")
    }
    


    // MARK: - 20. UTILITY FUNCTIONS
    
    /// Mask PII data
    private func maskPII(_ input: String) -> String {
        guard input.count > 6 else { return String(repeating: "*", count: input.count) }
        let visibleLength = min(3, input.count / 4)
        let visible = input.prefix(visibleLength)
        let masked = String(repeating: "*", count: input.count - visibleLength)
        return "\(visible)\(masked)"
    }

    
    /// Mask phone number specifically
    private func maskPhoneNumber(_ phone: String) -> String {
        guard phone.count >= 10 else { return "***" }
        let countryCode = phone.hasPrefix("+") ? phone.prefix(3) : ""
        let lastTwo = phone.suffix(2)
        let maskedLength = phone.count - countryCode.count - 2
        return "\(countryCode)-\(String(repeating: "*", count: maskedLength))\(lastTwo)"
    }
    
    /// Mask email
    private func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***" }
        let username = email[..<atIndex]
        let domain = email[atIndex...]
        
        let visibleUsername = username.prefix(2)
        let maskedUsername = String(repeating: "*", count: max(0, username.count - 2))
        return "\(visibleUsername)\(maskedUsername)\(domain)"
    }
    
    /// Get current timestamp in ISO 8601 format
    private func currentTimestamp() -> String {
        return ISO8601DateFormatter().string(from: Date())
    }
    
    // MARK: - 21. SESSION MANAGEMENT
    
    /// Generate unique session ID
    static func generateSessionId() -> String {
        return UUID().uuidString
    }
    
    
    
    /// Log session start
    func logSessionStart(sessionId: String, userId: String?, deviceId: String?, appVersion: String) {
        let maskedUserId = maskPII(userId ?? "anonymous")
        let timestamp = currentTimestamp()
        
        os_log("[SECURITY] Session started - SessionID: %{public}@, UserID: %{private}@, DeviceID: %{private}@, AppVersion: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               maskedUserId,
               deviceId ?? "unknown",
               appVersion,
               timestamp)
    }
    
    /// Log session end
    func logSessionEnd(sessionId: String, userId: String?, duration: TimeInterval, reason: String) {
        let maskedUserId = maskPII(userId ?? "anonymous")
        let timestamp = currentTimestamp()
        
        os_log("[SECURITY] Session ended - SessionID: %{public}@, UserID: %{private}@, Duration: %.2fs, Reason: %{public}@, Timestamp: %{public}@",
               log: securityLog,
               type: .info,
               sessionId,
               maskedUserId,
               duration,
               reason,
               timestamp)
    }
}
