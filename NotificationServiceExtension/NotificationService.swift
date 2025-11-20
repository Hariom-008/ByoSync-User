import UserNotifications
import UniformTypeIdentifiers

private func log(_ msg: String) {
    print("🟩 [NSE] \(msg)")
}

final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private let cryptoManager = CryptoManager.shared

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            log("❌ bestAttemptContent is nil")
            contentHandler(request.content)
            return
        }

        log("📬 Notification triggered")
        log("📦 Full UserInfo: \(content.userInfo)")

        // Log all keys individually for safety
        content.userInfo.forEach { key, value in
            log("🔑 Key: \(key) | Value: \(value)")
        }

        let rawBody: String
        if let bodyFromData = content.userInfo["body"] as? String {
            log("📨 RAW body from data.body: \(bodyFromData)")
            rawBody = bodyFromData
        } else {
            rawBody = content.body
            log("📨 RAW body from content.body: \(rawBody)")
        }

        // ✅ Now this uses the shared token-decrypting logic
        let decryptedBody = decryptPaymentBodyIfNeeded(rawBody)

        log("✅ FINAL Decrypted body: \(decryptedBody)")
        content.body = decryptedBody
        
        
        // IMAGE LOGGING
        var imageURLString: String?
        if let customImage = content.userInfo["image"] as? String {
            imageURLString = customImage
            log("🖼 Found image in data.image: \(customImage)")
        } else if let fcmOptions = content.userInfo["fcm_options"] as? [String: Any],
                  let image = fcmOptions["image"] as? String {
            imageURLString = image
            log("🖼 Found image in fcm_options.image: \(image)")
        } else {
            log("⚠️ No image found in payload")
        }

        guard let imageURLString = imageURLString,
              let url = URL(string: imageURLString) else {
            log("⚠️ Invalid image URL")
            contentHandler(content)
            return
        }

        log("⬇️ Downloading image from URL: \(url.absoluteString)")

        downloadImage(from: url) { [weak self] localURL in
            guard let self = self, let content = self.bestAttemptContent else {
                log("❌ NSE expired before attaching media")
                contentHandler(request.content)
                return
            }

            if let localURL = localURL {
                log("📁 Image saved at: \(localURL.path)")
                self.attachMedia(to: content, from: localURL)
            } else {
                log("❌ Image download failed")
            }

            contentHandler(content)
        }
    }


    override func serviceExtensionTimeWillExpire() {
        print("⏰ Extension time expiring, delivering notification")
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }

    // MARK: - Decryption helpers

    /// Wraps `decryptedMessage` but falls back to the raw body if decryption fails.
    private func decryptPaymentBodyIfNeeded(_ rawBody: String) -> String {
        let candidate = cryptoManager.decryptPaymentMessage(rawBody)
        return candidate.isEmpty ? rawBody : candidate
    }



    private func downloadImage(from url: URL, completion: @escaping (URL?) -> Void) {
        log("🌐 Starting image download...")

        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: url) { data, response, error in

            if let error = error {
                log("❌ Image download error: \(error)")
                completion(nil)
                return
            }

            log("📡 HTTP Response mimeType: \(response?.mimeType ?? "nil")")
            log("📊 Image size: \(data?.count ?? 0) bytes")

            guard let data = data else {
                log("❌ No data received")
                completion(nil)
                return
            }

            let ext = self.fileExtension(fromMimeType: response?.mimeType ?? "", url: url)
            log("🗂 Using file extension: \(ext)")

            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                try data.write(to: tmpURL)
                log("💾 Saved image at: \(tmpURL.path)")
                completion(tmpURL)
            } catch {
                log("❌ Failed to write image: \(error)")
                completion(nil)
            }
        }

        task.resume()
    }

    private func attachMedia(to content: UNMutableNotificationContent, from url: URL) {
        do {
            var options: [AnyHashable: Any]? = nil

            if #available(iOS 14.0, *) {
                let ext = url.pathExtension.lowercased()
                if let utType = utType(for: ext) {
                    options = [UNNotificationAttachmentOptionsTypeHintKey: utType.identifier]
                }
            }

            let attachment = try UNNotificationAttachment(
                identifier: "notification-image",
                url: url,
                options: options
            )

            content.attachments = [attachment]
            print("🎉 Media attachment added successfully")

        } catch {
            print("❌ Failed to create attachment: \(error.localizedDescription)")
        }
    }

    // MARK: - File Type Helpers

    @available(iOS 14.0, *)
    private func utType(for ext: String) -> UTType? {
        switch ext.lowercased() {
        case "png":  return .png
        case "gif":  return .gif
        case "jpg", "jpeg": return .jpeg
        case "webp": return .webP   // iOS 14+
        default:     return nil
        }
    }

    private func fileExtension(fromMimeType mimeType: String, url: URL) -> String {
        if mimeType.contains("png") { return "png" }
        if mimeType.contains("jpeg") || mimeType.contains("jpg") { return "jpg" }
        if mimeType.contains("gif") { return "gif" }
        if mimeType.contains("webp") { return "webp" }
        
        // Fallback to URL extension
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "jpg" : ext
    }
}
