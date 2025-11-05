////
////  CameraSpecView.swift
////  ByoSync
////
////  Enhanced camera specifications with live capture
////
//
//import SwiftUI
//import AVFoundation
//import Combine
//import simd
//
//struct CameraSpecs {
//    let deviceName: String
//    let position: String
//    
//    // Per-frame specs
//    let exposureDuration: Double
//    let iso: Float
//    let lensPosition: Float
//    let zoomFactor: Float
//    
//    // Static specs
//    let focalLength: Float
//    let fieldOfView: Float
//    let minISO: Float
//    let maxISO: Float
//    
//    // Frame info
//    let frameWidth: Int
//    let frameHeight: Int
//    let videoOrientation: AVCaptureVideoOrientation
//    
//    // Calibration data
//    let intrinsicMatrix: matrix_float3x3?
//    let intrinsicMatrixReferenceDimensions: CGSize?
//    let lensDistortionLookupTable: Data?
//    let inverseLensDistortionLookupTable: Data?
//    let lensDistortionCenter: CGPoint?
//    
//    // Video stabilization
//    let videoStabilizationMode: AVCaptureVideoStabilizationMode
//    
//    // Timestamp
//    let timestamp: CMTime?
//}
//
//final class CameraSpecManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
//    @Published var currentSpecs: CameraSpecs?
//    
//    private var captureSession: AVCaptureSession?
//    private var videoOutput: AVCaptureVideoDataOutput?
//    private var captureDevice: AVCaptureDevice?
//    private var videoConnection: AVCaptureConnection?
//    
//    func printCameraSpecs() {
//        guard let specs = currentSpecs else {
//            print("📷 No camera specifications available")
//            return
//        }
//        
//        print("\n" + String(repeating: "=", count: 50))
//        print("📷 CAMERA SPECIFICATIONS (LIVE)")
//        print(String(repeating: "=", count: 50))
//        
//        // Device info
//        print("🎯 Device: \(specs.deviceName)")
//        print("🔁 Position: \(specs.position)")
//        
//        // Per-frame specs
//        print("\n📊 PER-FRAME SPECIFICATIONS:")
//        print("⏱ Exposure Duration: \(String(format: "%.6f", specs.exposureDuration)) s")
//        print("💡 ISO: \(String(format: "%.0f", specs.iso))")
//        print("🔍 Lens Position: \(String(format: "%.3f", specs.lensPosition)) (0=∞, 1=closest)")
//        print("🔎 Zoom Factor: \(String(format: "%.2f", specs.zoomFactor))x")
//        if let timestamp = specs.timestamp {
//            let seconds = CMTimeGetSeconds(timestamp)
//            print("⏰ Timestamp: \(String(format: "%.6f", seconds)) s")
//        }
//        
//        // Static specs
//        print("\n🔧 STATIC SPECIFICATIONS:")
//        print("🧮 Aperture: f/\(String(format: "%.1f", specs.focalLength))")
//        print("🌐 Field of View: \(String(format: "%.2f", specs.fieldOfView))°")
//        print("🧾 ISO Range: \(String(format: "%.0f", specs.minISO)) - \(String(format: "%.0f", specs.maxISO))")
//        
//        // Frame info
//        print("\n📐 FRAME INFORMATION:")
//        print("📏 Resolution: \(specs.frameWidth) × \(specs.frameHeight)")
//        print("🔄 Video Orientation: \(orientationString(specs.videoOrientation))")
//        print("🎬 Video Stabilization: \(stabilizationString(specs.videoStabilizationMode))")
//        
//        // Calibration data
//        print("\n📸 CAMERA CALIBRATION DATA:")
//        if let intrinsic = specs.intrinsicMatrix {
//            print("✅ Intrinsic Matrix (3×3):")
//            print("   [\(String(format: "%.2f", intrinsic.columns.0.x)), \(String(format: "%.2f", intrinsic.columns.1.x)), \(String(format: "%.2f", intrinsic.columns.2.x))]")
//            print("   [\(String(format: "%.2f", intrinsic.columns.0.y)), \(String(format: "%.2f", intrinsic.columns.1.y)), \(String(format: "%.2f", intrinsic.columns.2.y))]")
//            print("   [\(String(format: "%.2f", intrinsic.columns.0.z)), \(String(format: "%.2f", intrinsic.columns.1.z)), \(String(format: "%.2f", intrinsic.columns.2.z))]")
//            
//            if let dims = specs.intrinsicMatrixReferenceDimensions {
//                print("   Reference Dimensions: \(Int(dims.width)) × \(Int(dims.height))")
//            }
//        } else {
//            print("❌ Intrinsic Matrix: Not available")
//        }
//        
//        if let center = specs.lensDistortionCenter {
//            print("📍 Lens Distortion Center: (\(String(format: "%.2f", center.x)), \(String(format: "%.2f", center.y)))")
//        }
//        
//        if let lut = specs.lensDistortionLookupTable {
//            print("🔍 Forward Lens Distortion LUT: \(lut.count) bytes")
//        } else {
//            print("❌ Forward Lens Distortion LUT: Not available")
//        }
//        
//        if let inverseLut = specs.inverseLensDistortionLookupTable {
//            print("🔄 Inverse Lens Distortion LUT: \(inverseLut.count) bytes")
//        } else {
//            print("❌ Inverse Lens Distortion LUT: Not available")
//        }
//        
//        print(String(repeating: "=", count: 50) + "\n")
//    }
//    
//    private func orientationString(_ orientation: AVCaptureVideoOrientation) -> String {
//        switch orientation {
//        case .portrait: return "Portrait (0°)"
//        case .portraitUpsideDown: return "Portrait Upside Down (180°)"
//        case .landscapeRight: return "Landscape Right (90°)"
//        case .landscapeLeft: return "Landscape Left (270°)"
//        @unknown default: return "Unknown"
//        }
//    }
//    
//    private func stabilizationString(_ mode: AVCaptureVideoStabilizationMode) -> String {
//        switch mode {
//        case .off: return "Off"
//        case .standard: return "Standard"
//        case .cinematic: return "Cinematic"
//        case .cinematicExtended: return "Cinematic Extended"
//        case .auto: return "Auto"
//        @unknown default: return "Unknown"
//        }
//    }
//    
//    func startCapture() {
//        // Request camera permission
//        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
//            guard granted else {
//                print("❌ Camera access denied")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                self?.setupCaptureSession()
//            }
//        }
//    }
//    
//    private func setupCaptureSession() {
//        captureSession = AVCaptureSession()
//        guard let session = captureSession else { return }
//        
//        session.beginConfiguration()
//        
//        // Get front camera
//        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
//                                                   for: .video,
//                                                   position: .front) else {
//            print("❌ No front camera found")
//            return
//        }
//        
//        self.captureDevice = device
//        
//        do {
//            let input = try AVCaptureDeviceInput(device: device)
//            if session.canAddInput(input) {
//                session.addInput(input)
//            }
//            
//            // Setup video output
//            let output = AVCaptureVideoDataOutput()
//            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.specs"))
//            
//            if session.canAddOutput(output) {
//                session.addOutput(output)
//                self.videoOutput = output
//            }
//            
//            // Get the connection and enable intrinsic matrix delivery
//            if let connection = output.connection(with: .video) {
//                self.videoConnection = connection
//                connection.videoOrientation = .portrait
//                
//                // Enable camera intrinsic matrix delivery
//                if connection.isCameraIntrinsicMatrixDeliverySupported {
//                    connection.isCameraIntrinsicMatrixDeliveryEnabled = true
//                    print("✅ Camera intrinsic matrix delivery enabled")
//                } else {
//                    print("⚠️ Camera intrinsic matrix delivery not supported")
//                }
//                
//                // Enable video stabilization if available
//                if connection.isVideoStabilizationSupported {
//                    connection.preferredVideoStabilizationMode = .auto
//                }
//            }
//            
//            session.commitConfiguration()
//            
//            // Start the session on a background thread
//            DispatchQueue.global(qos: .userInitiated).async {
//                session.startRunning()
//            }
//            
//        } catch {
//            print("⚠️ Camera setup failed: \(error.localizedDescription)")
//        }
//    }
//    
//    func stopCapture() {
//        captureSession?.stopRunning()
//        captureSession = nil
//    }
//    
//    // AVCaptureVideoDataOutputSampleBufferDelegate
//    func captureOutput(_ output: AVCaptureOutput,
//                      didOutput sampleBuffer: CMSampleBuffer,
//                      from connection: AVCaptureConnection) {
//        
//        guard let device = captureDevice else { return }
//        
//        // Get per-frame metadata
//        let exposureDuration = device.exposureDuration.seconds
//        let iso = device.iso
//        let lensPosition = device.lensPosition
//        let zoomFactor = device.videoZoomFactor
//        
//        // Get frame dimensions
//        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
//        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
//        
//        // Get timestamp
//        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//        
//        // Get camera calibration data
//        var intrinsicMatrix: matrix_float3x3?
//        var intrinsicMatrixReferenceDimensions: CGSize?
//        var lensDistortionLookupTable: Data?
//        var inverseLensDistortionLookupTable: Data?
//        var lensDistortionCenter: CGPoint?
//        
//        if let calibrationData = CMGetAttachment(sampleBuffer,
//                                                 key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
//                                                 attachmentModeOut: nil) as? Data {
//            calibrationData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
//                if let baseAddress = ptr.baseAddress, ptr.count >= MemoryLayout<matrix_float3x3>.size {
//                    intrinsicMatrix = baseAddress.assumingMemoryBound(to: matrix_float3x3.self).pointee
//                }
//            }
//        }
//        
//        // Try to get AVCameraCalibrationData from metadata
//        if let metadataDict = CMGetAttachment(sampleBuffer,
//                                             key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
//                                             attachmentModeOut: nil) as? NSDictionary {
//            // Additional calibration data would be here if available
//        }
//        
//        // Alternative: check format for calibration data
//        // Note: Full AVCameraCalibrationData is typically only available through ARKit or depth data output
//        
//        let specs = CameraSpecs(
//            deviceName: device.localizedName,
//            position: device.position == .front ? "Front" : "Back",
//            exposureDuration: exposureDuration,
//            iso: iso,
//            lensPosition: lensPosition,
//            zoomFactor: Float(zoomFactor),
//            focalLength: device.lensAperture,
//            fieldOfView: device.activeFormat.videoFieldOfView,
//            minISO: device.activeFormat.minISO,
//            maxISO: device.activeFormat.maxISO,
//            frameWidth: Int(dimensions.width),
//            frameHeight: Int(dimensions.height),
//            videoOrientation: connection.videoOrientation,
//            intrinsicMatrix: intrinsicMatrix,
//            intrinsicMatrixReferenceDimensions: intrinsicMatrixReferenceDimensions,
//            lensDistortionLookupTable: lensDistortionLookupTable,
//            inverseLensDistortionLookupTable: inverseLensDistortionLookupTable,
//            lensDistortionCenter: lensDistortionCenter,
//            videoStabilizationMode: connection.activeVideoStabilizationMode,
//            timestamp: timestamp
//        )
//        
//        DispatchQueue.main.async {
//            self.currentSpecs = specs
//        }
//    }
//}
//
//struct CameraSpecView: View
//
//struct SpecRow: View {
//    let icon: String
//    let label: String
//    let value: String
//    
//    var body: some View {
//        HStack {
//            Text("\(icon) \(label):")
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//            Spacer()
//            Text(value)
//                .font(.subheadline)
//                .foregroundColor(.primary)
//        }
//    }
//}
