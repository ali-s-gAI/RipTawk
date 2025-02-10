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
    @State private var scrollPosition: String?
    @Environment(\.scenePhase) private var scenePhase
    
    init() {}  // Remove UITabBar appearance configuration
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.projects) { project in
                    FeedVideoView(
                        project: project,
                        isActive: scrollPosition == project.id,
                        viewModel: viewModel
                    )
                    .id(project.id)
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea(.container, edges: [.top, .leading, .trailing])
        .background(.black)
        .onAppear {
            Task {
                await viewModel.loadFeedVideos()
                // Set initial scroll position immediately when we have projects
                if let firstId = viewModel.projects.first?.id {
                    scrollPosition = firstId
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                print("📱 App entering background - pausing playback")
                viewModel.cleanupAllPlayers()
            case .active:
                print("📱 App becoming active")
            @unknown default:
                break
            }
        }
    }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var projects: [VideoProject] = []
    var videoURLCache: [String: URL] = [:]
    var players: [String: AVPlayer] = [:]
    var preloadedIndices = Set<String>()
    
    // Keep these private
    private var activeDownloads: Set<String> = []
    private let fileManager = FileManager.default
    private var cachePath: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("videoCache")
    }
    
    init() {
        // Create cache directory if needed
        if let path = cachePath {
            try? fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    // Clean up players when view model is deinitialized
    deinit {
        for player in players.values {
            player.pause()
        }
        players.removeAll()
    }
    
    func preloadVideo(at index: Int, currentIndex: Int) async {
        guard index < projects.count,
              !preloadedIndices.contains(projects[index].id) else {
            print("⏭️ Skipping preload - already loaded or invalid index")
            return
        }
        
        let project = projects[index]
        
        do {
            print("🔄 Preloading video at index \(index)")
            let url = try await getVideoURL(for: project.videoFileId)
            videoURLCache[project.videoFileId] = url
            
            if players[project.id] == nil {
                let player = AVPlayer(url: url)
                player.automaticallyWaitsToMinimizeStalling = false
                
                let playerItem = player.currentItem
                playerItem?.preferredForwardBufferDuration = 3.0
                
                if let asset = playerItem?.asset {
                    try? await asset.load(.duration, .tracks)
                }
                
                players[project.id] = player
                preloadedIndices.insert(project.id)
                print("✅ Player created and preloaded for index \(index)")
            }
            
            // Only preload next video if within reasonable range (e.g., next 2 videos)
            if index == currentIndex && index + 1 < projects.count && index - currentIndex < 2 {
                await preloadVideo(at: index + 1, currentIndex: currentIndex)
            }
            
        } catch {
            print("❌ Error preloading video: \(error)")
        }
    }
    
    func loadFeedVideos() async {
        do {
            print("📚 Starting to load feed videos")
            let projects = try await AppwriteService.shared.listUserVideos()
            self.projects = projects
            print("📚 Loaded \(projects.count) videos")
            
            // Immediately start preloading first video
            if !projects.isEmpty {
                print("🔄 Preloading first video")
                await preloadVideo(at: 0, currentIndex: 0)
            }
        } catch {
            print("❌ Error loading feed videos: \(error)")
        }
    }
    
    func cacheVideoURL(_ url: URL?, for fileId: String) {
        videoURLCache[fileId] = url
    }
    
    func cleanupAllPlayers() {
        print("🧹 Cleaning up all players")
        for (_, player) in players {
            print("⏹️ Pausing player")
            player.pause()
        }
    }
    
    func getVideoURL(for fileId: String) async throws -> URL {
        // Check memory cache first
        if let cachedURL = videoURLCache[fileId] {
            print("📎 Using memory-cached URL for \(fileId)")
            // Ensure file still exists
            if cachedURL.isFileURL && FileManager.default.fileExists(atPath: cachedURL.path) {
                return cachedURL
            } else {
                videoURLCache.removeValue(forKey: fileId)
            }
        }
        
        // Check disk cache
        if let localURL = getCachedVideoURL(for: fileId) {
            print("📎 Using disk-cached video for \(fileId)")
            videoURLCache[fileId] = localURL
            return localURL
        }
        
        // Prevent concurrent downloads of the same video
        guard !activeDownloads.contains(fileId) else {
            print("⏳ Waiting for existing download of \(fileId)")
            // Wait for existing download
            while activeDownloads.contains(fileId) {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            if let url = videoURLCache[fileId] {
                return url
            }
            throw NSError(domain: "", code: -1)
        }
        
        activeDownloads.insert(fileId)
        defer { activeDownloads.remove(fileId) }
        
        // Download and cache
        print("📥 Downloading video \(fileId)")
        let url = try await AppwriteService.shared.getVideoURL(fileId: fileId)
        
        // Cache to disk
        if let localURL = try? await cacheVideo(from: url, fileId: fileId) {
            videoURLCache[fileId] = localURL
            return localURL
        }
        
        return url
    }
    
    private func getCachedVideoURL(for fileId: String) -> URL? {
        guard let cachePath = cachePath else { return nil }
        // Use ".mp4" extension for consistent lookups
        let videoURL = cachePath.appendingPathComponent(fileId).appendingPathExtension("mp4")
        return fileManager.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    private func cacheVideo(from url: URL, fileId: String) async throws -> URL? {
        guard let cachePath = cachePath else { return nil }
        // Always end with ".mp4"
        let destinationURL = cachePath.appendingPathComponent(fileId).appendingPathExtension("mp4")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let mimeType = response.mimeType, mimeType.starts(with: "video/") else {
                print("❌ Invalid content type received")
                throw NSError(domain: "", code: -1)
            }
            
            // Remove old file to avoid partial/corrupt reuse
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try data.write(to: destinationURL)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destinationURL.path)
            print("💾 Cached video \(fileId) to disk at \(destinationURL)")
            return destinationURL
        } catch {
            print("❌ Error caching video: \(error)")
            return nil
        }
    }
}

struct FeedVideoView: View {
    let project: VideoProject
    let isActive: Bool
    let viewModel: FeedViewModel
    @State private var editProject: VideoProject? = nil
    @StateObject private var playerHolder = PlayerHolder()
    @State private var isLiked = false
    @State private var isPlaying = true
    @State private var showCoinAnimation = false
    @State private var lastTapPosition: CGPoint = .zero
    @State private var showVideoEditor = false
    
    // Reset state when video becomes inactive
    private func handleInactiveState() {
        isPlaying = true  // Reset to true when video becomes inactive
        playerHolder.player?.pause()
        // Don't seek to zero or cleanup player here
    }
    
    var body: some View {
        ZStack {
            if let currentPlayer = playerHolder.player {
                CustomVideoPlayer(player: currentPlayer)
                    .containerRelativeFrame([.horizontal, .vertical])
            } else {
                Color.black
                    .containerRelativeFrame([.horizontal, .vertical])
                ProgressView("Loading video...")
            }
            
            // Expanded tap area with updated gesture handling for single and double taps
            Color.clear
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .contentShape(Rectangle())
                .ignoresSafeArea(edges: .all)
                // Capture tap location using a drag gesture (minimumDistance: 0)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            lastTapPosition = value.location
                        }
                )
                // High priority double-tap gesture
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            handleDoubleTap()
                        }
                )
                // Single tap gesture for play/pause toggle
                .onTapGesture {
                    handleSingleTap()
                }
            
            // Play button
            if !isPlaying {
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Coin animation
            if showCoinAnimation {
                CoinAnimation(
                    isVisible: $showCoinAnimation,
                    position: lastTapPosition
                )
            }
            
            // UI Overlay
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Video info on the left
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Author: \(project.userId)")
                            .font(.appHeadline())
                        Text(project.title)
                            .font(.appBody())
                        Text("Video description...")
                            .font(.appCaption())
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Updated action buttons
                    VStack(spacing: 28) {
                        ActionButton(
                            icon: isLiked ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis",
                            text: isLiked ? "1" : "0",
                            action: { handleLike() },
                            iconColor: isLiked ? Color.brandPrimary : .white
                        )
                        
                        ActionButton(
                            icon: "bubble.right",
                            text: "0",
                            action: {
                                // Implement comment action
                            }
                        )
                        
                        ActionButton(
                            icon: "arrowshape.turn.up.forward",
                            text: "Share",
                            action: {
                                // Implement share action
                            }
                        )
                        
                        ActionButton(
                            icon: "square.and.pencil",
                            text: "Edit",
                            action: {
                                handleEdit()
                            }
                        )
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 8)
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
        .onChange(of: isActive) { _, newValue in
            if newValue {
                if playerHolder.player == nil {
                    print("onChange: Active and no player – loading video for project \(project.id)")
                    loadVideo()
                } else {
                    print("onChange: Active and player exists – restarting video for project \(project.id)")
                    if isPlaying {
                        playerHolder.player?.play()
                    }
                }
            } else {
                print("onChange: Inactive – pausing video for project \(project.id)")
                handleInactiveState()
            }
        }
        .onDisappear {
            print("📱 FeedVideoView disappeared - pausing and cleaning up player")
            playerHolder.player?.pause()
            playerHolder.cleanup()
        }
        // Replace the existing sheet with fullScreenCover
        .fullScreenCover(isPresented: $showVideoEditor) {
            if let videoURL = viewModel.videoURLCache[project.videoFileId] {
                VideoEditorSwiftUIView(video: nil, existingProject: project)
                    .overlay(alignment: .topLeading) {
                        Button {
                            showVideoEditor = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding()
                        }
                    }
            }
        }
    }
    
    private func loadVideo() {
        Task {
            do {
                print("🎥 Loading video for project \(project.id)")
                let url = try await viewModel.getVideoURL(for: project.videoFileId)
                await setupPlayer(with: url, projectId: project.id)
                if isActive {
                    playerHolder.player?.play()
                }
            } catch {
                print("❌ Error loading video: \(error)")
            }
        }
    }
    
    private func setupPlayer(with url: URL, projectId: String) async {
        print("🎬 Setting up player for project \(projectId) with URL: \(url.absoluteString)")
        
        let asset = AVURLAsset(url: url)
        do {
            let item = AVPlayerItem(asset: asset)
            let status = try await item.asset.load(.isPlayable)
            guard status else {
                print("❌ Asset is not playable for project \(projectId)")
                return
            }
            
            // Remove any existing player and observers first
            if let existingPlayer = playerHolder.player {
                NotificationCenter.default.removeObserver(self, 
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: existingPlayer.currentItem)
                existingPlayer.pause()
                existingPlayer.replaceCurrentItem(with: nil)
            }
            
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = false
            player.actionAtItemEnd = .none
            
            // New: Loop the video
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            
            await MainActor.run {
                playerHolder.player = player
                if isActive {
                    print("▶️ Auto-playing video \(projectId)")
                    player.play()
                }
            }
        } catch {
            print("❌ Error setting up player: \(error)")
        }
    }
    
    private func handleSingleTap() {
        isPlaying.toggle()
        if let currentPlayer = playerHolder.player {
            print("handleSingleTap: isPlaying = \(isPlaying), player rate before: \(currentPlayer.rate)")
            if isPlaying {
                currentPlayer.play()
            } else {
                currentPlayer.pause()
            }
            print("handleSingleTap: player rate after: \(currentPlayer.rate)")
        } else {
            print("handleSingleTap: No player available")
        }
    }
    
    private func handleDoubleTap() {
        print("handleDoubleTap: double tap received")
        showCoinAnimation = true
        handleLike()
        
        // Play haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Hide animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showCoinAnimation = false
        }
    }
    
    private func handleLike() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
        }
        
        // Play haptic feedback for better feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // TODO: Implement like functionality with backend
    }
    
    private func handleEdit() {
        playerHolder.player?.pause()
        isPlaying = false
        // Check if we have the video URL cached
        if viewModel.videoURLCache[project.videoFileId] != nil {
            showVideoEditor = true
        } else {
            // If URL not cached, load it first
            Task {
                do {
                    _ = try await viewModel.getVideoURL(for: project.videoFileId)
                    await MainActor.run {
                        showVideoEditor = true
                    }
                } catch {
                    print("❌ Error loading video for editing: \(error)")
                    // You might want to show an error alert here
                }
            }
        }
    }
}

// Update PlayerHolder to enhance cleanup
class PlayerHolder: ObservableObject {
    @Published var player: AVPlayer?
    
    deinit {
        print("🗑️ PlayerHolder being deinitialized")
        cleanup()
    }
    
    func cleanup() {
        if let player = player {
            NotificationCenter.default.removeObserver(self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem)
        }
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
        controller.videoGravity = .resizeAspectFill
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
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 35))
                    .foregroundColor(iconColor)
                
                if let text = text {
                    Text(text)
                        .font(.appCaption())
                        .foregroundColor(.white)
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

// Update CoinAnimation for better visual effect
struct CoinAnimation: View {
    @Binding var isVisible: Bool
    let position: CGPoint
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { index in
                CoinParticle(
                    index: index,
                    isVisible: isVisible,
                    position: position
                )
            }
        }
    }
}

struct CoinParticle: View {
    let index: Int
    let isVisible: Bool
    let position: CGPoint
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "dollarsign.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(Color.brandPrimary)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .position(x: position.x, y: position.y)
            .onAppear {
                if isVisible {
                    let startAngle = Double.random(in: -30...30)
                    let distance = CGFloat.random(in: 100...200)
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        scale = 1
                        opacity = 1
                        rotation = Double.random(in: -360...360)
                        // Initial burst upward
                        offset = CGSize(
                            width: cos(startAngle * .pi / 180) * 20,
                            height: -20
                        )
                    }
                    
                    // Fall down with physics-like motion
                    withAnimation(.easeIn(duration: 0.7).delay(0.1)) {
                        offset = CGSize(
                            width: cos(startAngle * .pi / 180) * distance,
                            height: distance // Positive for downward movement
                        )
                        opacity = 0
                        scale = 0.5
                        rotation += Double.random(in: 180...360)
                    }
                }
            }
    }
}

