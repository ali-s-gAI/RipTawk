//
//  VideosView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import PhotosUI
import AVKit
import VideoEditorSDK
import UIKit

struct VideosView: View {
    @StateObject private var projectManager = ProjectManager()
    @State private var showMediaPicker = false
    @State private var editingProject: VideoProject?
    @State private var showTitleEdit = false
    @State private var projectToDelete: VideoProject?
    @State private var showDeleteConfirmation = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(projectManager.projects) { project in
                        ProjectGridItem(project: project, onTitleTap: {
                            editingProject = project
                            showTitleEdit = true
                        })
                        .transition(.scale)
                        .contextMenu {
                            Button(role: .destructive) {
                                projectToDelete = project
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("My Videos")
            .toolbar {
                Button(action: {
                    showMediaPicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
            .sheet(isPresented: $showMediaPicker) {
                MediaPickerView(isPresented: $showMediaPicker) { url in
                    Task {
                        await projectManager.createProject(with: url)
                    }
                }
            }
            .alert("Edit Title", isPresented: $showTitleEdit) {
                if let project = editingProject {
                    TextField("Title", text: .constant(project.title))
                    Button("Save") {
                        // TODO: Implement title update in Appwrite
                        showTitleEdit = false
                    }
                    Button("Cancel", role: .cancel) {
                        showTitleEdit = false
                    }
                }
            }
            .alert("Delete Project", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let project = projectToDelete {
                        Task {
                            do {
                                try await AppwriteService.shared.deleteVideo(project)
                                // Remove from local array
                                projectManager.projects.removeAll { $0.id == project.id }
                            } catch {
                                print("❌ Error deleting project: \(error)")
                                // TODO: Show error alert to user
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this project? This action cannot be undone.")
            }
            .task {
                await projectManager.loadProjects()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProjectGridItem: View {
    let project: VideoProject
    let onTitleTap: () -> Void
    @State private var thumbnail: UIImage?
    @State private var editedTitle: String
    @State private var showEditor = false
    @State private var isPressed = false

    init(project: VideoProject, onTitleTap: @escaping () -> Void) {
        self.project = project
        self.onTitleTap = onTitleTap
        self._editedTitle = State(initialValue: project.title)
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showEditor = true
                isPressed = false
            }
        } label: {
            VStack(spacing: 0) {
                // Thumbnail
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(9/16, contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .aspectRatio(9/16, contentMode: .fill)
                                .overlay {
                                    ProgressView()
                                }
                        }
                    }
                    .overlay {
                        // Video Duration Overlay
                        Text(formatDuration(project.duration))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .padding(8)
                    }
                    
                    // Title Overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.5), .clear]),
                        startPoint: .bottom,
                        endPoint: .center
                    )
                    .overlay {
                        VStack(alignment: .leading) {
                            Spacer()
                            Text(project.title)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                        }
                    }
                }
            }
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(radius: 2)
            .padding(4)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showEditor) {
            VideoEditorSwiftUIView(video: nil, existingProject: project)
                .overlay(alignment: .topLeading) {
                    Button {
                        showEditor = false
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
        .onAppear {
            if let cached = ThumbnailCache.shared.getImage(for: project.videoFileId) {
                thumbnail = cached
            } else {
                Task {
                    if let image = await generateThumbnail() {
                        thumbnail = image
                        ThumbnailCache.shared.setImage(image, for: project.videoFileId)
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func generateThumbnail() async -> UIImage? {
        // Check if thumbnail exists in cache
        let fileManager = FileManager.default
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let thumbnailURL = cachePath.appendingPathComponent("\(project.videoFileId)_thumb.jpg")
        
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let cachedImage = UIImage(contentsOfFile: thumbnailURL.path) {
            return cachedImage
        }
        
        // Generate new thumbnail
        do {
            let videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 1, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            
            // Cache the thumbnail
            if let data = image.jpegData(compressionQuality: 0.7) {
                try data.write(to: thumbnailURL)
            }
            
            return image
        } catch {
            print("Thumbnail generation error: \(error)")
            return nil
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoDetailView: View {
    let project: VideoProject
    @State private var videoURL: URL?

    var body: some View {
        VStack {
            if let url = videoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .navigationTitle(project.title)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ProgressView("Loading video...")
                    .navigationTitle(project.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            do {
                videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
            } catch {
                print("❌ Error loading video URL for project \(project.id): \(error)")
            }
        }
    }
}

struct MediaPickerView: View {
    @Binding var isPresented: Bool
    let onSelect: (URL) -> Void
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showEditor = false
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 1,
                matching: .videos
            ) {
                Text("Select Video")
                    .font(.headline)
            }
            .onChange(of: selectedItems) { _, items in
                guard let item = items.first else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        
                        let fileName = "video_\(UUID().uuidString).mov"
                        let fileURL = documentsDirectory.appendingPathComponent(fileName)
                        
                        try data.write(to: fileURL)
                        await MainActor.run {
                            selectedVideoURL = fileURL
                            showEditor = true
                        }
                    }
                }
            }
            .navigationTitle("Add Video")
            .toolbar {
                Button("Cancel") {
                    isPresented = false
                }
            }
            .fullScreenCover(isPresented: $showEditor) {
                if let url = selectedVideoURL {
                    VideoEditorSwiftUIView(video: url)
                        .onDisappear {
                            // Only upload if the editor was dismissed with confirmation
                            if let url = selectedVideoURL {
                                onSelect(url)
                                isPresented = false
                            }
                        }
                }
            }
        }
    }
}

@MainActor
class ProjectManager: ObservableObject {
    @Published var projects: [VideoProject] = []
    @Published var syncStatus: [String: Bool] = [:] // Track sync status for each project
    private let appwriteService = AppwriteService.shared
    
    func loadProjects() async {
        do {
            projects = try await appwriteService.listUserVideos()
            print("📥 Loaded \(projects.count) projects from Appwrite")
        } catch {
            print("❌ Error loading projects: \(error)")
        }
    }
    
    func createProject(with videoURL: URL) async {
        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            // Create a default title with date and time
            let defaultTitle = "Project \(dateFormatter.string(from: Date()))"
            
            // Save to local storage first
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let savedURL = documentsURL.appendingPathComponent("video_\(UUID().uuidString).mov")
            
            try FileManager.default.copyItem(at: videoURL, to: savedURL)
            
            // Create project in Appwrite
            let project = try await appwriteService.uploadVideo(
                url: savedURL,
                title: defaultTitle,
                duration: duration
            )
            
            // Add to projects list
            projects.append(project)
            print("✅ Created new project with ID: \(project.id)")
            
        } catch {
            print("❌ Error creating project: \(error)")
        }
    }
    
    func updateProject(_ project: VideoProject, with videoURL: URL) async {
        do {
            let asset = AVURLAsset(url: videoURL)
            let duration = try await asset.load(.duration).seconds
            
            // Save to local storage first
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let savedURL = documentsURL.appendingPathComponent("video_\(UUID().uuidString).mov")
            
            try FileManager.default.copyItem(at: videoURL, to: savedURL)
            
            // Update project in Appwrite
            let updatedProject = try await appwriteService.updateVideo(
                project: project,
                newVideoURL: savedURL,
                duration: duration
            )
            
            // Update in local array
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = updatedProject
            }
            print("✅ Updated project with ID: \(project.id)")
            
        } catch {
            print("❌ Error updating project: \(error)")
        }
    }
    
    func updateProjectTitle(_ project: VideoProject, newTitle: String) async {
        do {
            let updatedProject = try await appwriteService.updateProjectTitle(project, newTitle: newTitle)
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = updatedProject
            }
            print("✅ Updated project title: \(project.id)")
        } catch {
            print("❌ Error updating project title: \(error)")
        }
    }
}

// Helper extension for date formatting
extension DateFormatter {
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

