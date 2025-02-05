import SwiftUI
import AVKit
import VideoEditorSDK

struct VideoPreviewView: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?
    @State private var shouldNavigateToEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
                
                VStack {
                    HStack {
                        Button(action: { 
                            print("🎥 [PREVIEW] User tapped Dismiss")
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
                            // Clean up player
                            player?.pause()
                            player = nil
                            // Dismiss all the way back
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
                        // Clean up player before navigating
                        player?.pause()
                        player = nil
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
