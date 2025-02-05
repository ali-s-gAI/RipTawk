import SwiftUI
import AVKit
import VideoEditorSDK

struct VideoPreviewView: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @Binding var recordedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var shouldNavigateToEditor = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
                
                VStack {
                    HStack {
                        Button(action: { 
                            print("🎥 [PREVIEW] User tapped Dismiss")
                            player?.pause()
                            player = nil
                            isPresented = false 
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 40) {
                        Button(action: { 
                            print("🎥 [PREVIEW] User tapped Retake")
                            player?.pause()
                            player = nil
                            recordedVideoURL = nil
                            isPresented = false 
                        }) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title)
                                Text("Retake")
                                    .font(.callout)
                            }
                            .foregroundColor(.white)
                        }
                        
                        Button(action: { 
                            print("🎥 [PREVIEW] User tapped Continue")
                            shouldNavigateToEditor = true 
                        }) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                Text("Continue")
                                    .font(.callout)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToEditor) {
                VideoEditorSwiftUIView(video: Video(url: videoURL))
                    .onAppear {
                        print("🎥 [PREVIEW] Navigating to editor")
                        player?.pause()
                        player = nil
                        // Set the recorded URL when continuing to editor
                        recordedVideoURL = videoURL
                        // Dismiss the preview
                        isPresented = false
                    }
            }
        }
        .onAppear {
            print("🎥 [PREVIEW] View appeared, setting up player for: \(videoURL.path)")
            player = AVPlayer(url: videoURL)
            player?.play()
            
            // Loop the video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                print("🎥 [PREVIEW] Video reached end, looping")
                player?.seek(to: .zero)
                player?.play()
            }
        }
        .onDisappear {
            print("🎥 [PREVIEW] View disappeared, cleaning up player")
            player?.pause()
            player = nil
            // Remove notification observer
            NotificationCenter.default.removeObserver(self)
        }
    }
} 
