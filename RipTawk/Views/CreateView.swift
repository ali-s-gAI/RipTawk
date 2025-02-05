import SwiftUI
import AVKit
import AVFoundation
import VideoEditorSDK
import Photos

struct CreateView: View {
    @State private var showCamera = false
    @State private var recordedVideoURL: URL?
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = recordedVideoURL {
                    NavigationLink(destination: VideoEditorSwiftUIView(video: Video(url: url))) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("Continue to Editor")
                                .font(.headline)
                        }
                        .padding()
                    }
                } else {
                    Button {
                        showCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 50))
                            Text("Record Video")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            .navigationTitle("Create")
            .fullScreenCover(isPresented: $showCamera) {
                NavigationView {
                    CameraRecordingView(recordedVideoURL: $recordedVideoURL, isPresented: $showCamera)
                        .ignoresSafeArea()
                        .navigationBarHidden(true)
                }
            }
        }
    }
}

struct CameraRecordingView: View {
    @Binding var recordedVideoURL: URL?
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager()
    @State private var showPreview = false
    @State private var previewURL: URL?
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                
                Spacer()
                
                // Record button
                Button(action: {
                    if cameraManager.isRecording {
                        cameraManager.stopRecording()
                    } else {
                        cameraManager.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 8)
                            .frame(width: 84, height: 84)
                        
                        if cameraManager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.red)
                                .frame(width: 36, height: 36)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, url in
            if let url = url {
                previewURL = url
                showPreview = true
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let url = previewURL {
                VideoPreviewView(videoURL: url, isPresented: $showPreview)
                    .onDisappear {
                        if recordedVideoURL != nil {
                            isPresented = false
                        }
                    }
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraManager: NSObject, ObservableObject {
    @Published var recordedVideoURL: URL?
    @Published var isRecording = false
    
    let captureSession = AVCaptureSession()
    var videoOutput: AVCaptureMovieFileOutput?
    
    override init() {
        super.init()
        setupCaptureSession()
        checkPhotoLibraryPermission()
    }
    
    private func checkPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            if status != .authorized {
                print("Photos access not authorized")
            }
        }
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        }
        
        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        videoOutput?.stopRecording()
        isRecording = false
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            // Save to Photos library
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
            } completionHandler: { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.recordedVideoURL = outputFileURL
                    }
                } else if let error = error {
                    print("Error saving to Photos: \(error.localizedDescription)")
                }
            }
        } else {
            print("Error recording video: \(error?.localizedDescription ?? "unknown error")")
        }
    }
}
