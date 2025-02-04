//
//  EditorView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct EditorView: View {
    let videoURL: URL
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    @State private var selectedTool: EditingTool = .none
    @State private var appliedFilters: [VideoFilter] = []
    @State private var addedText: [TextOverlay] = []
    @State private var selectedMusic: Music?

    enum EditingTool {
        case none
        case filter
        case text
        case music
        case effects
        case trim
    }

    var body: some View {
        VStack {
            VideoPlayerView(videoURL: videoURL, currentTime: $currentTime, duration: $duration, isPlaying: $isPlaying)
                .frame(height: 300)
            
            VideoTimelineView(currentTime: $currentTime, duration: duration)
                .frame(height: 50)
            
            HStack(spacing: 20) {
                EditingToolButton(tool: .trim, selectedTool: $selectedTool)
                EditingToolButton(tool: .filter, selectedTool: $selectedTool)
                EditingToolButton(tool: .text, selectedTool: $selectedTool)
                EditingToolButton(tool: .music, selectedTool: $selectedTool)
                EditingToolButton(tool: .effects, selectedTool: $selectedTool)
            }
            .padding()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    switch selectedTool {
                    case .filter:
                        ForEach(VideoFilter.allCases, id: \.self) { filter in
                            FilterThumbnail(filter: filter, isSelected: appliedFilters.contains(filter))
                                .onTapGesture {
                                    toggleFilter(filter)
                                }
                        }
                    case .text:
                        Button("Add Text") {
                            addTextOverlay()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    case .music:
                        ForEach(Music.sampleMusic, id: \.id) { music in
                            MusicThumbnail(music: music, isSelected: selectedMusic == music)
                                .onTapGesture {
                                    selectedMusic = music
                                }
                        }
                    case .effects:
                        Text("Effects coming soon!")
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
            
            HStack {
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                
                Text(timeString(time: currentTime))
                Spacer()
                Text(timeString(time: duration))
                
                Button("Save") {
                    saveEditedVideo()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    func timeString(time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func toggleFilter(_ filter: VideoFilter) {
        if let index = appliedFilters.firstIndex(of: filter) {
            appliedFilters.remove(at: index)
        } else {
            appliedFilters.append(filter)
        }
    }
    
    func addTextOverlay() {
        let newText = TextOverlay(id: UUID(), text: "New Text", position: .center, color: .white, fontSize: 24)
        addedText.append(newText)
    }
    
    func saveEditedVideo() {
        // Implement video saving logic with applied edits
        print("Saving video with \(appliedFilters.count) filters, \(addedText.count) text overlays, and music: \(selectedMusic?.title ?? "None")")
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let videoURL: URL
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isPlaying: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        
        duration = player.currentItem?.duration.seconds ?? 0
        
        let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: nil) { time in
            currentTime = time.seconds
        }
        
        context.coordinator.player = player
        context.coordinator.timeObserver = timeObserver
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isPlaying {
            context.coordinator.player?.play()
        } else {
            context.coordinator.player?.pause()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VideoPlayerView
        var player: AVPlayer?
        var timeObserver: Any?
        
        init(_ parent: VideoPlayerView) {
            self.parent = parent
        }
        
        deinit {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
        }
    }
}

struct VideoTimelineView: View {
    @Binding var currentTime: Double
    let duration: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: CGFloat(currentTime / duration) * geometry.size.width)
            }
        }
    }
}

struct EditingToolButton: View {
    let tool: EditorView.EditingTool
    @Binding var selectedTool: EditorView.EditingTool
    
    var body: some View {
        Button(action: {
            selectedTool = tool
        }) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(selectedTool == tool ? .blue : .gray)
        }
    }
    
    var iconName: String {
        switch tool {
        case .trim: return "scissors"
        case .filter: return "camera.filters"
        case .text: return "textformat"
        case .music: return "music.note"
        case .effects: return "sparkles"
        case .none: return "xmark"
        }
    }
}

enum VideoFilter: String, CaseIterable {
    case none, sepia, mono, vintage, vibrant
}

struct FilterThumbnail: View {
    let filter: VideoFilter
    let isSelected: Bool
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(filter.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.white)
                )
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct TextOverlay: Identifiable {
    let id: UUID
    var text: String
    var position: TextPosition
    var color: Color
    var fontSize: CGFloat
    
    enum TextPosition {
        case topLeft, topRight, center, bottomLeft, bottomRight
    }
}

struct Music: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    let url: URL
    
    static var sampleMusic: [Music] = [
        Music(id: UUID(), title: "Happy Beat", artist: "Artist 1", duration: 180, url: URL(string: "sample1")!),
        Music(id: UUID(), title: "Energetic Pop", artist: "Artist 2", duration: 200, url: URL(string: "sample2")!),
        Music(id: UUID(), title: "Chill Vibes", artist: "Artist 3", duration: 160, url: URL(string: "sample3")!)
    ]
}

struct MusicThumbnail: View {
    let music: Music
    let isSelected: Bool
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    VStack {
                        Text(music.title)
                            .font(.caption)
                            .foregroundColor(.white)
                        Text(music.artist)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                )
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

