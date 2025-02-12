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
                    .frame(width: UIScreen.main.bounds.width,
                           height: UIScreen.main.bounds.height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition)
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea(.all)
        .background(.black)
        .task {
            await loadInitialContent()
        }
        .onChange(of: scrollPosition) { _, newPosition in
            guard let newPosition else { return }
            print("📜 Scroll position changed to: \(newPosition)")
            
            if let currentIndex = viewModel.projects.firstIndex(where: { $0.id == newPosition }) {
                Task {
                    await viewModel.preloadVideo(at: currentIndex, currentIndex: currentIndex)
                    if currentIndex + 1 < viewModel.projects.count {
                        await viewModel.preloadVideo(at: currentIndex + 1, currentIndex: currentIndex)
                    }
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
                // Reload current video when becoming active
                if let currentPosition = scrollPosition {
                    Task {
                        if let index = viewModel.projects.firstIndex(where: { $0.id == currentPosition }) {
                            await viewModel.preloadVideo(at: index, currentIndex: index)
                        }
                    }
                }
            @unknown default:
                break
            }
        }
    }
    
    private func loadInitialContent() async {
        if viewModel.projects.isEmpty {
            await viewModel.loadFeedVideos()
        }
        
        if scrollPosition == nil, let firstId = viewModel.projects.first?.id {
            scrollPosition = firstId
        }
    }
}

// Create a new VideoLoader class that's not on the main actor
class VideoLoader {
    private var downloadTasks: [String: Task<URL, Error>] = [:]
    private let fileManager = FileManager.default
    var cachePath: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("videoCache")
    }
    
    init() {
        if let path = cachePath {
            try? fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    func getVideoURL(for fileId: String) async throws -> URL {
        // If we have a Task in progress, await it
        if let existingTask = downloadTasks[fileId] {
            return try await existingTask.value
        }
        
        // Create new download task
        let task = Task<URL, Error> {
            // Check disk cache first
            if let localURL = getCachedVideoURL(for: fileId),
               FileManager.default.fileExists(atPath: localURL.path) {
                print("📎 Using disk-cached video for \(fileId)")
                return localURL
            }
            
            // Download and cache
            print("📥 Downloading video \(fileId)")
            let url = try await AppwriteService.shared.getVideoURL(fileId: fileId)
            
            if let localURL = try? await cacheVideo(from: url, fileId: fileId) {
                return localURL
            }
            
            return url
        }
        
        downloadTasks[fileId] = task
        defer { downloadTasks.removeValue(forKey: fileId) }
        
        return try await task.value
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

@MainActor
class FeedViewModel: ObservableObject {
    @Published var projects: [VideoProject] = []
    private var videoLoader = VideoLoader()
    private var activePreloads: Set<String> = []
    var videoURLCache: [String: URL] = [:]
    
    init() {
        if let path = videoLoader.cachePath {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    func loadFeedVideos() async {
        do {
            print("📚 Starting to load feed videos")
            // Simplified async call
            let projects = try await AppwriteService.shared.listUserVideos()
            self.projects = projects
            print("�� Loaded \(projects.count) videos")
            
            // Start preloading first video if available
            if !projects.isEmpty {
                print("🔄 Preloading first video")
                await preloadVideo(at: 0, currentIndex: 0)
            }
        } catch {
            print("❌ Error loading feed videos: \(error)")
        }
    }
    
    func preloadVideo(at index: Int, currentIndex: Int) async {
        guard index < projects.count else { return }
        
        let project = projects[index]
        
        // Skip if already preloading
        guard !activePreloads.contains(project.id) else {
            print("🔄 Already preloading video \(project.id)")
            return
        }
        
        activePreloads.insert(project.id)
        defer { activePreloads.remove(project.id) }
        
        do {
            print("🔄 Preloading video at index \(index)")
            let url = try await videoLoader.getVideoURL(for: project.videoFileId)
            
            // Cache the URL
            videoURLCache[project.videoFileId] = url
        } catch {
            print("❌ Error preloading video: \(error)")
        }
    }
    
    func getVideoURL(for fileId: String) async throws -> URL {
        let url = try await videoLoader.getVideoURL(for: fileId)
        videoURLCache[fileId] = url
        return url
    }
    
    func cacheVideoURL(_ url: URL?, for fileId: String) {
        // This method is no longer used in the new implementation
    }
    
    func cleanupAllPlayers() {
        print("🧹 Cleaning up video URL cache")
        // Only remove URLs for non-visible videos
        videoURLCache.removeAll()
        activePreloads.removeAll()
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
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let currentPlayer = playerHolder.player {
                    CustomVideoPlayer(player: currentPlayer)
                        .frame(width: geometry.size.width, 
                               height: geometry.size.height)
                        .clipped()
                } else {
                    Color.black
                        .frame(width: geometry.size.width, 
                               height: geometry.size.height)
                    if isLoading {
                        ProgressView("Loading video...")
                    }
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
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.all)
        .onAppear {
            print("📱 FeedVideoView appeared for \(project.id)")
            loadVideoIfNeeded()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                print("🎬 Video \(project.id) becoming active")
                loadVideoIfNeeded()
            } else {
                print("⏸️ Video \(project.id) becoming inactive")
                playerHolder.player?.pause()
            }
        }
        .onDisappear {
            print("📱 FeedVideoView disappeared for \(project.id)")
            cleanupPlayer()
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
    
    private func loadVideoIfNeeded() {
        // If we already have a valid player, just play it
        if let player = playerHolder.player {
            if isPlaying {
                player.play()
            }
            return
        }
        
        // Otherwise, load the video
        isLoading = true
        
        Task {
            do {
                print("🎥 Loading video for project \(project.id)")
                let url = try await viewModel.getVideoURL(for: project.videoFileId)
                
                // Check if we're still active before continuing
                guard isActive else {
                    print("⚠️ Video \(project.id) no longer active, cancelling load")
                    return
                }
                
                // Load asset in background
                let asset = AVURLAsset(url: url)
                try? await asset.load(.duration, .tracks)
                
                // Check active state again
                guard isActive else {
                    print("⚠️ Video \(project.id) no longer active after asset load")
                    return
                }
                
                // Setup player on main actor
                await MainActor.run {
                    let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                    player.automaticallyWaitsToMinimizeStalling = false
                    player.actionAtItemEnd = .none
                    
                    // Add loop observer
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem,
                        queue: .main
                    ) { [weak player] _ in
                        player?.seek(to: .zero)
                        player?.play()
                    }
                    
                    playerHolder.player = player
                    isLoading = false
                    
                    if isPlaying && isActive {
                        player.play()
                    }
                }
            } catch {
                print("❌ Error loading video \(project.id): \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        print("🧹 Cleaning up player for \(project.id)")
        playerHolder.cleanup()
        isPlaying = true
        isLoading = false
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
    
    func cleanup() {
        if player != nil {
            NotificationCenter.default.removeObserver(self)
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }
    
    deinit {
        cleanup()
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
        
        // Ensure proper layout
        controller.view.backgroundColor = .black
        
        // Don't set frame here - let parent view handle sizing
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

