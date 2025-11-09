//
//  SocketManager.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 09.11.2025.
//

import Foundation
import SwiftUI
import SocketIO
import Combine

// MARK: - Socket.IO Manager
class SocketIOManager: ObservableObject {
    static let shared = SocketIOManager()
    
    @Published var isConnected = false
    @Published var receivedMessages: [PaymentNotification] = []
    @Published var connectionStatus = "Disconnected"
    @Published var socketId: String = ""
    
    // Add these properties for overlay management
    @Published var showPaymentOverlay = false
    @Published var currentPaymentNotification: PaymentNotification?
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
  
    
    init(urlString: String = "http://192.168.1.12:7000") {
        setupSocket(urlString: urlString)
    }
    
    private func setupSocket(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        manager = SocketManager(socketURL: url, config: [
            .log(true),
            .compress,
            .forceWebsockets(false), // Allow polling fallback
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(1)
        ])
        
        socket = manager.defaultSocket
        
        // Setup event listeners
        setupEventListeners()
    }
    
    private func setupEventListeners() {
        // Connection events
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.connectionStatus = "Connected"
                self?.socketId = self?.socket.sid ?? ""
                print("✅ Connected:", self?.socket.sid ?? "")
                
                // Register merchant (like your HTML example)
                self?.registerUser(userId: UserSession.shared.currentUser?.userId ?? "")
                print("Connected Socket for user with userID: \(UserSession.shared.currentUser?.userId ?? "nil")")
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.connectionStatus = "Disconnected"
                print("❌ Disconnected")
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.connectionStatus = "Error: \(data)"
                print("⚠️ Error:", data)
            }
        }
        
        socket.on(clientEvent: .reconnect) { [weak self] data, ack in
            DispatchQueue.main.async {
                self?.connectionStatus = "Reconnected"
                print("🔄 Reconnected")
            }
        }
        
        // Listen for payment received event - FIXED VERSION
        socket.on("paymentReceived") { [weak self] data, ack in
            guard let self = self else { return }
            
            print("💰 Raw Payment Received Event:", data)
            
            DispatchQueue.main.async {
                do {
                    // Convert socket data to JSON
                    if let dataArray = data as? [[String: Any]],
                       let paymentData = dataArray.first {
                        
                        // Parse the response structure
                        if let jsonData = try? JSONSerialization.data(withJSONObject: paymentData),
                           let response = try? JSONDecoder().decode(PaymentReceivedResponse.self, from: jsonData) {
                            
                            // Create PaymentNotification from response
                            let notification = PaymentNotification(
                                id: response.order.id,
                                amount: Double(response.order.coins),
                                currency: "Coins",
                                senderName: response.order.senderId, // You might want to fetch actual name
                                timestamp: Date(),
                                transactionId: response.order.id,
                                message: response.message,
                                orderType: response.order.type
                            )
                            
                            // Add to array
                            self.receivedMessages.append(notification)
                            
                            // Set current notification and show overlay
                            self.currentPaymentNotification = notification
                            self.showPaymentOverlay = true
                            
                            print("✅ Payment notification created:", notification)
                        }
                    } else if let paymentDict = data.first as? [String: Any] {
                        // Alternative parsing if data structure is different
                        let notification = self.parsePaymentNotification(from: paymentDict)
                        
                        // Add to array
                        self.receivedMessages.append(notification)
                        
                        // Set current notification and show overlay
                        self.currentPaymentNotification = notification
                        self.showPaymentOverlay = true
                        
                        print("✅ Payment notification created (alternative):", notification)
                    }
                } catch {
                    print("❌ Error parsing payment notification:", error)
                }
            }
        }
        
        // Listen for any custom events
        socket.on("message") { [weak self] data, ack in
            DispatchQueue.main.async {
                print("📨 Received message:", data)
            }
        }
    }
    
    // Helper function to parse payment notification from dictionary
    private func parsePaymentNotification(from dict: [String: Any]) -> PaymentNotification {
        let id = dict["_id"] as? String ?? UUID().uuidString
        let amount = dict["amount"] as? Double ?? (dict["coins"] as? Double ?? 0)
        let currency = dict["currency"] as? String ?? "Coins"
        let senderName = dict["sender_name"] as? String ?? dict["senderId"] as? String ?? "Unknown"
        let transactionId = dict["transaction_id"] as? String ?? dict["_id"] as? String ?? ""
        let message = dict["message"] as? String
        let orderType = dict["order_type"] as? String ?? dict["type"] as? String
        
        return PaymentNotification(
            id: id,
            amount: amount,
            currency: currency,
            senderName: senderName,
            timestamp: Date(),
            transactionId: transactionId,
            message: message,
            orderType: orderType
        )
    }
    
    // Connect to server
    func connect() {
        connectionStatus = "Connecting..."
        socket.connect()
    }
    
    // Disconnect from server
    func disconnect() {
        socket.disconnect()
        connectionStatus = "Disconnected"
        isConnected = false
    }
    
    // Register merchant (like your HTML example)
    func registerUser(userId: String) {
        socket.emit("registerUser", userId)
        print("📤 Registered user:", userId)
    }
    
    // Send custom message
    func sendMessage(_ message: String) {
        socket.emit("message", message)
        print("📤 Sent:", message)
    }
    
    // Emit custom event
    func emitEvent(event: String, data: Any) {
        socket.emit(event, data as! SocketData)
        print("📤 Event '\(event)':", data)
    }
    
    // Clear current payment notification
    func dismissCurrentPayment() {
        withAnimation {
            showPaymentOverlay = false
            currentPaymentNotification = nil
        }
    }
}
