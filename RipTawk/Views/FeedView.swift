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
    @EnvironmentObject private var projectManager: ProjectManager
    
    init() {}  // Remove UITabBar appearance configuration
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(projectManager.projects) { project in
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
            Task { @MainActor in
                // If we already have projects but no scroll position, restore it
                if !projectManager.projects.isEmpty && scrollPosition == nil {
                    scrollPosition = projectManager.projects.first?.id
                    // Preload the first video again
                    await viewModel.preloadVideo(at: 0, currentIndex: 0)
                } else if projectManager.projects.isEmpty {
                    // Only load feed videos if we don't have any
                    await projectManager.loadProjects()
                    if let firstId = projectManager.projects.first?.id {
                        scrollPosition = firstId
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
                        if let index = projectManager.projects.firstIndex(where: { $0.id == currentPosition }) {
                            await viewModel.preloadVideo(at: index, currentIndex: index)
                        }
                    }
                }
            @unknown default:
                break
            }
        }
    }
}

// Create a new VideoLoader class that's not on the main actor
class VideoLoader {
    private var downloadTasks: [String: Task<URL, Error>] = [:]
    private let fileManager = FileManager.default
    private let lock = NSLock() // Add lock for thread safety
    
    var cachePath: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("videoCache")
    }
    
    init() {
        if let path = cachePath {
            try? fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    func getVideoURL(for fileId: String) async throws -> URL {
        // Guard against empty fileId
        guard !fileId.isEmpty else {
            throw NSError(domain: "VideoLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid fileId"])
        }
        
        // Thread-safe task access
        lock.lock()
        let existingTask = downloadTasks[fileId]
        lock.unlock()
        
        // If we have a Task in progress, await it
        if let task = existingTask {
            do {
                return try await task.value
            } catch {
                // If task failed, remove it and try again
                lock.lock()
                downloadTasks.removeValue(forKey: fileId)
                lock.unlock()
                throw error
            }
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
        
        // Thread-safe task storage
        lock.lock()
        downloadTasks[fileId] = task
        lock.unlock()
        
        do {
            let result = try await task.value
            
            // Thread-safe task cleanup
            lock.lock()
            downloadTasks.removeValue(forKey: fileId)
            lock.unlock()
            
            return result
        } catch {
            // Thread-safe task cleanup on error
            lock.lock()
            downloadTasks.removeValue(forKey: fileId)
            lock.unlock()
            throw error
        }
    }
    
    private func getCachedVideoURL(for fileId: String) -> URL? {
        guard !fileId.isEmpty,
              let cachePath = cachePath else { return nil }
        let videoURL = cachePath.appendingPathComponent(fileId).appendingPathExtension("mp4")
        return fileManager.fileExists(atPath: videoURL.path) ? videoURL : nil
    }
    
    private func cacheVideo(from url: URL, fileId: String) async throws -> URL? {
        guard !fileId.isEmpty,
              let cachePath = cachePath else { return nil }
        
        let destinationURL = cachePath.appendingPathComponent(fileId).appendingPathExtension("mp4")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let mimeType = response.mimeType, mimeType.starts(with: "video/") else {
                print("❌ Invalid content type received")
                throw NSError(domain: "VideoLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid content type"])
            }
            
            // Remove old file in a thread-safe way
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
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
    
    func cleanup() {
        lock.lock()
        downloadTasks.forEach { $0.value.cancel() }
        downloadTasks.removeAll()
        lock.unlock()
    }
}

// Thread-safe storage class that can be accessed from any context
private final class ThreadSafeStorage {
    private let lock = NSLock()
    private var urlCache: [String: URL] = [:]
    private let videoLoader = VideoLoader()
    
    func getURLCache() -> [String: URL] {
        lock.lock()
        defer { lock.unlock() }
        return urlCache
    }
    
    func setURLCache(_ cache: [String: URL]) {
        lock.lock()
        urlCache = cache
        lock.unlock()
    }
    
    func clearURLCache() {
        lock.lock()
        urlCache.removeAll()
        lock.unlock()
    }
    
    func cleanup() {
        clearURLCache()
        videoLoader.cleanup()
    }
    
    func getVideoLoader() -> VideoLoader {
        videoLoader
    }
}

@MainActor
class FeedViewModel: ObservableObject {
    @Published var projects: [VideoProject] = []
    @Published var userNames: [String: String] = [:] // Map of userIds to names
    private var isLoadingFeed = false
    private var cleanupTask: Task<Void, Never>?
    private let storage = ThreadSafeStorage()
    
    // Keep these for URL management
    private var activeDownloads: Set<String> = []
    
    var videoURLCache: [String: URL] {
        get { storage.getURLCache() }
        set { storage.setURLCache(newValue) }
    }
    
    init() {
        if let path = storage.getVideoLoader().cachePath {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
    
    func cleanupAllPlayers() {
        print("🧹 Cleaning up video URL cache")
        storage.cleanup()
        cleanupTask?.cancel()
    }
    
    nonisolated func cleanup() {
        print("🗑️ FeedViewModel cleanup started")
        storage.cleanup()
        print("🗑️ FeedViewModel cleanup completed")
    }
    
    deinit {
        cleanup()
    }
    
    func loadFeedVideos() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        
        do {
            print("📚 Starting to load feed videos")
            let projects = try await AppwriteService.shared.listUserVideos()
            
            // Fetch user names for all unique user IDs
            let uniqueUserIds = Set(projects.map { $0.userId })
            for userId in uniqueUserIds {
                do {
                    let name = try await AppwriteService.shared.getUserName(userId: userId)
                    await MainActor.run {
                        self.userNames[userId] = name
                    }
                } catch {
                    print("⚠️ Could not fetch name for user \(userId): \(error)")
                    await MainActor.run {
                        self.userNames[userId] = "Unknown User"
                    }
                }
            }
            
            await MainActor.run {
                self.projects = projects
                print("📚 Loaded \(projects.count) videos")
                
                // Start preloading first video if available
                if !projects.isEmpty {
                    print("🔄 Preloading first video")
                    Task {
                        await self.preloadVideo(at: 0, currentIndex: 0)
                    }
                }
            }
        } catch {
            print("❌ Error loading feed videos: \(error)")
        }
        
        isLoadingFeed = false
    }
    
    func preloadVideo(at index: Int, currentIndex: Int) async {
        guard index < projects.count else { return }
        
        let project = projects[index]
        guard !project.videoFileId.isEmpty else { return }
        
        do {
            print("🔄 Preloading video at index \(index)")
            let url = try await storage.getVideoLoader().getVideoURL(for: project.videoFileId)
            
            // Thread-safe URL cache update
            var cache = storage.getURLCache()
            cache[project.videoFileId] = url
            storage.setURLCache(cache)
            
        } catch {
            print("❌ Error preloading video: \(error)")
        }
    }
    
    func getVideoURL(for fileId: String) async throws -> URL {
        guard !fileId.isEmpty else {
            throw NSError(domain: "FeedViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid fileId"])
        }
        
        let url = try await storage.getVideoLoader().getVideoURL(for: fileId)
        
        var cache = storage.getURLCache()
        cache[fileId] = url
        storage.setURLCache(cache)
        
        return url
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
    @State private var showAIInsights = false  // New state for AI sheet
    @State private var userName: String = "Loading..."  // Add local state
    @State private var isSharing = false
    @State private var shareItem: ShareItem?
    
    // Add this struct inside FeedVideoView
    struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    
    var body: some View {
        ZStack {
            if let currentPlayer = playerHolder.player {
                CustomVideoPlayer(player: currentPlayer)
                    .containerRelativeFrame([.horizontal, .vertical])
            } else {
                Color.black
                    .containerRelativeFrame([.horizontal, .vertical])
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
                        Text(userName)
                            .font(.appHeadline())
                        Text(project.title)
                            .font(.appBody())
                        if let description = project.description {
                            Text(description)
                                .font(.appCaption())
                        }
                        if let tags = project.tags, !tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.appCaption())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.brandPrimary.opacity(0.2))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.top, 4)
                        }
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
                            icon: "sparkles",
                            text: "AI",
                            action: {
                                showAIInsights = true
                            }
                        )
                        
                        ActionButton(
                            icon: "arrowshape.turn.up.forward",
                            text: "Share",
                            action: handleShare
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
        .onAppear {
            print("📱 FeedVideoView appeared for \(project.id)")
            loadVideoIfNeeded()
            // Add user name loading
            Task {
                do {
                    let name = try await AppwriteService.shared.getUserName(userId: project.userId)
                    print("👤 Loaded user name for \(project.userId): \(name)")
                    await MainActor.run {
                        userName = name
                    }
                } catch {
                    print("❌ Failed to load user name for \(project.userId): \(error)")
                }
            }
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
        .sheet(isPresented: $showAIInsights) {
            AIInsightsView(project: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Replace the existing share sheet presentation with this
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea()
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
    
    private func handleShare() {
        Task {
            do {
                let url = try await AppwriteService.shared.getShareableURL(fileId: project.videoFileId)
                print("🔗 Generated share URL: \(url)")
                await MainActor.run {
                    shareItem = ShareItem(url: url)  // Use ShareItem instead of separate URL and bool
                }
            } catch {
                print("❌ Failed to generate share URL: \(error)")
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

// Add new MarketDataView
struct MarketDataView: View {
    let ticker: String
    @State private var marketData: MarketData?
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedNews: NewsItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quote Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(ticker)
                        .font(.appHeadline())
                        .foregroundColor(.primary)
                    Spacer()
                    if isLoading {
                        ProgressView()
                    }
                }
                
                if let quote = marketData?.quote {
                    Text("$\(String(format: "%.2f", quote))")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.brandPrimary)
                } else if let error = error {
                    Text(error)
                        .font(.appCaption())
                        .foregroundColor(.red)
                }
            }
            
            // News Section
            if let news = marketData?.news, !news.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest News")
                        .font(.appHeadline())
                        .foregroundColor(.secondary)
                    
                    ForEach(news, id: \.headline) { item in
                        Button(action: { selectedNews = item }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.headline)
                                    .font(.appBody())
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                Text(item.source)
                                    .font(.appCaption())
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brandPrimary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedNews) { news in
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(news.headline)
                            .font(.appTitle())
                            .padding(.bottom, 4)
                        
                        HStack {
                            Text(news.source)
                                .font(.appCaption())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(news.updated))
                                .font(.appCaption())
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        Text(news.content)
                            .font(.appBody())
                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            selectedNews = nil
                        }
                    }
                }
            }
        }
        .task {
            await fetchMarketData()
        }
    }
    
    private func fetchMarketData() async {
        isLoading = true
        error = nil
        
        do {
            marketData = try await AppwriteService.shared.fetchMarketData(for: ticker)
        } catch {
            self.error = "Failed to fetch market data"
        }
        
        isLoading = false
    }
    
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Update AIInsightsView
struct AIInsightsView: View {
    let project: VideoProject
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicker: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("AI Insights")
                    .font(.appTitle())
                    .foregroundColor(.primary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 8)
            
            // Description Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.appHeadline())
                    .foregroundColor(.secondary)
                Text(project.description ?? "No description available")
                    .font(.appBody())
                    .foregroundColor(.primary)
            }
            
            // Tags Section with Tappable Tickers
            VStack(alignment: .leading, spacing: 8) {
                Text("Market Tickers")
                    .font(.appHeadline())
                    .foregroundColor(.secondary)
                
                if let tags = project.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Button(action: { selectedTicker = tag }) {
                                    Text(tag)
                                        .font(.appBody())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTicker == tag ? Color.brandPrimary : Color.brandPrimary.opacity(0.2))
                                        .foregroundColor(selectedTicker == tag ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                } else {
                    Text("No tickers found")
                        .font(.appBody())
                        .foregroundColor(.secondary)
                }
            }
            
            // Market Data Section
            if let ticker = selectedTicker {
                MarketDataView(ticker: ticker)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// Update ShareSheet to be more robust
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Fix iPad presentation
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = []
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, 
                                      y: UIScreen.main.bounds.midY, 
                                      width: 0, height: 0)
        }
        
        // Add completion handler
        controller.completionWithItemsHandler = { _, _, _, _ in
            // Handle completion if needed
            print("✅ Share sheet dismissed")
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Update if needed
    }
}
