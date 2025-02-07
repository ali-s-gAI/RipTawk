//
//  FeedView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVKit

// Note: We now use VideoProject (from AppwriteService) as our video model.

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    @Environment(\.scenePhase) private var scenePhase
    
    init() {}  // Remove UITabBar appearance configuration
    
    var body: some View {
        GeometryReader { geometry in
            if viewModel.projects.isEmpty {
                ProgressView("Loading videos...")
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(viewModel.projects.indices, id: \.self) { index in
                        FeedVideoView(
                            project: viewModel.projects[index],
                            isActive: currentIndex == index,
                            viewModel: viewModel,
                            index: index
                        )
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .tag(index)
                        .onAppear {
                            print("📱 Video \(index) appeared in view")
                            Task {
                                await viewModel.preloadVideo(at: index + 1)
                            }
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                // Pause old video, play newly visible video
                .onChange(of: currentIndex) { oldIndex, newIndex in
                    viewModel.pausePlayer(for: oldIndex)
                    viewModel.playPlayer(for: newIndex)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFeedVideos()
            }
        }
        // Handle app switching between tabs
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.pausePlayer(for: currentIndex)
                viewModel.cleanupAllPlayers()
            } else if newPhase == .active {
                viewModel.playPlayer(for: currentIndex)
            }
        }
        .onDisappear {
            viewModel.cleanupAllPlayers()
        }
    }
    
    private func preloadNextVideo(at index: Int) {
        guard index < viewModel.projects.count else { return }
        let nextProject = viewModel.projects[index]
        Task {
            // Cache video URL for smooth transitions
            if viewModel.videoURLCache[nextProject.videoFileId] == nil {
                let url = try? await AppwriteService.shared.getVideoURL(fileId: nextProject.videoFileId)
                viewModel.cacheVideoURL(url, for: nextProject.videoFileId)
            }
        }
    }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var projects: [VideoProject] = []
    var videoURLCache: [String: URL] = [:]
    var players: [Int: AVPlayer] = [:]
    
    // Track loading state
    private var isPreloading = false
    private var preloadedIndices = Set<Int>()
    
    // Clean up players when view model is deinitialized
    deinit {
        for player in players.values {
            player.pause()
        }
        players.removeAll()
    }
    
    func preloadVideo(at index: Int) async {
        guard index < projects.count,
              !preloadedIndices.contains(index),
              !isPreloading else {
            print("⏭️ Skipping preload for index \(index): already loaded or invalid")
            return
        }
        
        isPreloading = true
        print("🔄 Starting preload for video \(index)")
        
        do {
            let project = projects[index]
            if videoURLCache[project.videoFileId] == nil {
                print("📥 Fetching URL for video \(index)")
                let url = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
                videoURLCache[project.videoFileId] = url
                
                // Pre-create AVPlayer but don't start playing
                if players[index] == nil {
                    print("🎬 Pre-creating player for video \(index)")
                    let player = AVPlayer(url: url)
                    player.automaticallyWaitsToMinimizeStalling = false
                    // Preload the item
                    if let asset = player.currentItem?.asset {
                        try? await asset.load(.isPlayable)
                    }
                    players[index] = player
                }
                
                preloadedIndices.insert(index)
                print("✅ Successfully preloaded video \(index)")
            } else {
                print("📎 Using cached URL for video \(index)")
            }
        } catch {
            print("❌ Error preloading video \(index): \(error)")
        }
        
        isPreloading = false
    }
    
    func loadFeedVideos() async {
        do {
            print("📚 Starting to load feed videos")
            let projects = try await AppwriteService.shared.listUserVideos()
            self.projects = projects
            print("📚 Loaded \(projects.count) videos")
            
            // Preload first two videos immediately
            if !projects.isEmpty {
                await preloadVideo(at: 0)
                if projects.count > 1 {
                    await preloadVideo(at: 1)
                }
            }
        } catch {
            print("❌ Error loading feed videos: \(error)")
        }
    }
    
    func cacheVideoURL(_ url: URL?, for fileId: String) {
        videoURLCache[fileId] = url
    }
    
    func pausePlayer(for index: Int) {
        players[index]?.pause()
    }
    
    func playPlayer(for index: Int) {
        // First pause all players to prevent audio overlap
        for (_, player) in players {
            player.pause()
            player.seek(to: .zero)
        }
        // Then play the current one
        if let player = players[index] {
            player.seek(to: .zero)
            player.play()
        }
    }
    
    func cleanupAllPlayers() {
        for (_, player) in players {
            player.pause()
            player.seek(to: .zero)
            player.replaceCurrentItem(with: nil)
        }
        players.removeAll()
        preloadedIndices.removeAll()
    }
}

struct FeedVideoView: View {
    let project: VideoProject
    let isActive: Bool
    let viewModel: FeedViewModel
    let index: Int
    @StateObject private var playerHolder = PlayerHolder()
    @State private var isLiked = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = playerHolder.player {
                    CustomVideoPlayer(player: player)
                        // Fill screen while maintaining aspect ratio
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .background(Color.black)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    ProgressView("Loading video...")
                    .onAppear {
                        // Force load video if player is nil
                        loadVideo()
                    }
                }
                
                // UI Overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        // Video info on the left
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Author: \(project.userId)")
                                .font(.headline)
                            Text(project.title)
                                .font(.subheadline)
                            Text("Video description...")
                                .font(.body)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Action buttons on the right
                        VStack(spacing: 20) {
                            ActionButton(icon: isLiked ? "heart.fill" : "heart", text: "1200", action: {
                                isLiked.toggle()
                            }, iconColor: isLiked ? .red : .white)
                            
                            ActionButton(icon: "message", text: "45", action: {
                                // Implement comment action here.
                            })
                            
                            ActionButton(icon: "square.and.arrow.up", text: nil, action: {
                                // Implement share action here.
                            })
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                if playerHolder.player == nil {
                    loadVideo()
                } else {
                    playerHolder.player?.seek(to: .zero)
                    playerHolder.player?.play()
                }
            } else {
                playerHolder.player?.pause()
            }
        }
        // Listen for app state changes to handle background/foreground
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            playerHolder.player?.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if isActive {
                playerHolder.player?.play()
            }
        }
    }
    
    private func loadVideo() {
        Task {
            print("🎥 Starting to load video for index \(index)")
            if let cachedURL = viewModel.videoURLCache[project.videoFileId] {
                print("📎 Using cached URL for video \(index)")
                await setupPlayer(with: cachedURL, index: index)
            } else {
                do {
                    print("📥 Fetching URL for video \(index)")
                    let url = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
                    viewModel.cacheVideoURL(url, for: project.videoFileId)
                    await setupPlayer(with: url, index: index)
                } catch {
                    print("❌ Error loading video URL: \(error)")
                }
            }
        }
    }
    
    private func setupPlayer(with url: URL, index: Int) async {
        print("🎬 Setting up player for video \(index)")
        let player = AVPlayer(url: url)
        // Prevent blocking main thread with synchronous loading
        player.automaticallyWaitsToMinimizeStalling = false
        player.actionAtItemEnd = .none
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        await MainActor.run {
            viewModel.players[index] = player
            playerHolder.player = player
            if isActive {
                print("▶️ Auto-playing video \(index)")
                player.play()
            }
        }
    }
}

class PlayerHolder: ObservableObject {
    @Published var player: AVPlayer?
    
    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}

// Custom video player view that properly handles aspect ratio and filling
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// A reusable view for the action buttons (like, comment, share)
struct ActionButton: View {
    let icon: String
    let text: String?
    let action: () -> Void
    var iconColor: Color = .white
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(iconColor)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                if let text = text {
                    Text(text)
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            }
        }
    }
}

struct CommentsView: View {
    let video: VideoProject  // Changed from FeedVideo to VideoProject
    @State private var newComment = ""
    
    var body: some View {
        VStack {
            Text("Comments")
                .font(.title)
                .padding()
            
            // Using a placeholder comment count (e.g. 3) since VideoProject doesn't have a comments property.
            List {
                ForEach(1...3, id: \.self) { index in
                    CommentRow(username: "User\(index)", comment: "This is comment #\(index)")
                }
            }
            
            HStack {
                TextField("Add a comment", text: $newComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Post") {
                    // Implement post comment functionality
                    newComment = ""
                }
            }
            .padding()
        }
    }
}

struct CommentRow: View {
    let username: String
    let comment: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text(username)
                    .font(.headline)
                Text(comment)
                    .font(.subheadline)
            }
        }
    }
}

// Add this new struct for scroll tracking
struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

