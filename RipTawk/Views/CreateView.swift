import SwiftUI
import MijickCamera
import AVFoundation

struct CreateView: View {
    @State private var showCamera = false
    @State private var recordedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = recordedVideoURL {
                    NavigationLink(destination: EditorView(videoURL: url)) {
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
                            Image(systemName: "camera.fill")
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
            .sheet(isPresented: $showCamera) {
                MCamera()
                    .onVideoCaptured { videoURL, controller in
                        recordedVideoURL = videoURL
                        showCamera = false
                    }
                    .startSession()
                    .ignoresSafeArea()
            }
        }
    }
} 
