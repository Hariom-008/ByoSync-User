import SwiftUI
import SocketIO
import Combine

// MARK: - Socket.IO Manager
class SocketIOManager: ObservableObject {
    @Published var isConnected = false
    @Published var receivedMessages: [String] = []
    @Published var connectionStatus = "Disconnected"
    @Published var socketId: String = ""
    
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    
    init(urlString: String = "wss://192.168.1.16:7000") {
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
                self?.registerMerchant(merchantId: "6902fb5bf49da940520d6ee6")
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
        
        // Listen for payment received event (like your HTML example)
        socket.on("paymentReceived") { [weak self] data, ack in
            DispatchQueue.main.async {
                print("💰 Payment Received Event:", data)
                let message = "💰 Payment: \(data)"
                self?.receivedMessages.append(message)
            }
        }
        
        // Listen for any custom events
        socket.on("message") { [weak self] data, ack in
            DispatchQueue.main.async {
                let message = "Message: \(data)"
                self?.receivedMessages.append(message)
                print("📨 Received:", data)
            }
        }
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
    func registerMerchant(merchantId: String) {
        socket.emit("registerMerchant", merchantId)
        print("📤 Registered merchant:", merchantId)
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
}

// MARK: - SwiftUI View
struct SocketIOClientView: View {
    @StateObject private var socketManager = SocketIOManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status Card
                VStack(spacing: 10) {
                    HStack {
                        Circle()
                            .fill(socketManager.isConnected ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(socketManager.connectionStatus)
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    if !socketManager.socketId.isEmpty {
                        Text("Socket ID: \(socketManager.socketId)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Connect/Disconnect Buttons
                HStack(spacing: 15) {
                    Button(action: {
                        socketManager.connect()
                    }) {
                        Label("Connect", systemImage: "bolt.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(socketManager.isConnected ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(socketManager.isConnected)
                    
                    Button(action: {
                        socketManager.disconnect()
                    }) {
                        Label("Disconnect", systemImage: "xmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(socketManager.isConnected ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!socketManager.isConnected)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Received Messages
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Received Messages")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !socketManager.receivedMessages.isEmpty {
                            Button(action: {
                                socketManager.receivedMessages.removeAll()
                            }) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 8) {
                                if socketManager.receivedMessages.isEmpty {
                                    Text("No messages yet...")
                                        .foregroundColor(.gray)
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                } else {
                                    ForEach(Array(socketManager.receivedMessages.enumerated()), id: \.offset) { index, message in
                                        HStack {
                                            Text(message)
                                                .font(.system(.body, design: .monospaced))
                                                .padding(10)
                                                .background(
                                                    message.contains("💰") ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)
                                                )
                                                .cornerRadius(8)
                                            
                                            Spacer()
                                        }
                                        .id(index)
                                    }
                                }
                            }
                            .onChange(of: socketManager.receivedMessages.count) { _ in
                                if let lastIndex = socketManager.receivedMessages.indices.last {
                                    withAnimation {
                                        proxy.scrollTo(lastIndex, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .padding(.horizontal)
            }
        }
    }
}
