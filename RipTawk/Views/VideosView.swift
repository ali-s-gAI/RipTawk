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
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(projectManager.projects) { project in
                        ProjectGridItem(project: project) {
                            editingProject = project
                            showTitleEdit = true
                        }
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
                .padding()
            }
            .navigationTitle("My Projects")
            .toolbar {
                Button(action: {
                    showMediaPicker = true
                }) {
                    Image(systemName: "plus")
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
}

struct ProjectGridItem: View {
    let project: VideoProject
    let onTitleTap: () -> Void
    @State private var thumbnail: UIImage?
    @State private var videoURL: URL?
    @State private var editedTitle: String
    
    init(project: VideoProject, onTitleTap: @escaping () -> Void) {
        self.project = project
        self.onTitleTap = onTitleTap
        self._editedTitle = State(initialValue: project.title)
    }
    
    var body: some View {
        NavigationLink {
            if let url = videoURL {
                VideoEditorSwiftUIView(video: url, existingProject: project)
            } else {
                ProgressView("Loading video...")
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                Group {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(8)
                .clipped()
                
                // Title (tappable)
                Button(action: onTitleTap) {
                    Text(project.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Date
                Text(formatDate(project.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {  // Load video URL and thumbnail only once when the view appears
            if videoURL == nil {
                do {
                    videoURL = try await AppwriteService.shared.getVideoURL(fileId: project.videoFileId)
                    await generateThumbnail()
                } catch {
                    print("❌ Error loading video URL: \(error)")
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
    
    private func generateThumbnail() async {
        guard let videoURL = videoURL else { return }
        // Check if the thumbnail is cached
        if let cachedImage = ThumbnailCache.shared.getImage(for: project.videoFileId) {
            await MainActor.run { thumbnail = cachedImage }
            return
        }
        
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            let image = UIImage(cgImage: cgImage)
            await MainActor.run { thumbnail = image }
            ThumbnailCache.shared.setImage(image, for: project.videoFileId)
        } catch {
            print("❌ Error generating thumbnail: \(error)")
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

