import SwiftUI
import AVKit
import VideoEditorSDK

struct VideoPreviewView: View {
    let videoURL: URL
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?
    @State private var shouldNavigateToEditor = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
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
                
                HStack(spacing: 40) {
                    Button(action: { isPresented = false }) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Retake")
                                .font(.callout)
                        }
                        .foregroundColor(.white)
                    }
                    
                    NavigationLink(
                        destination: VideoEditorSwiftUIView(video: Video(url: videoURL)),
                        isActive: $shouldNavigateToEditor
                    ) {
                        Button(action: { shouldNavigateToEditor = true }) {
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                Text("Continue")
                                    .font(.callout)
                            }
                            .foregroundColor(.white)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
            player?.play()
            
            // Loop the video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player?.currentItem,
                queue: .main
            ) { _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
} 