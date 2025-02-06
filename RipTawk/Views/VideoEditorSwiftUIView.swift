import SwiftUI
import VideoEditorSDK
import AVFoundation

// Remove our custom Video struct since we'll use ImglyKit.Video directly
struct VideoEditorSwiftUIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedVideoURL: URL?
    @State private var showConfirmation = false
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @StateObject private var projectManager = ProjectManager()
    
    // The video being edited
    let video: URL
    var existingProject: VideoProject?
    
    // Control the presence of the VideoEditor view
    @State private var isEditorActive: Bool = true
    
    init(video url: URL, existingProject: VideoProject? = nil) {
        self.video = url
        self.existingProject = existingProject
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isEditorActive {
                    VideoEditor(video: ImglyKit.Video(url: video))
                        .onDidSave { result in
                            print("🎬 [EDITOR] Received edited video at \(result.output.url.absoluteString)")
                            editedVideoURL = result.output.url
                            showConfirmation = true
                        }
                        .onDidCancel {
                            print("🎬 [EDITOR] User cancelled editing")
                            cleanupAndDismiss()
                        }
                        .onDidFail { error in
                            print("🎬 [EDITOR] Error: \(error.localizedDescription)")
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                        .ignoresSafeArea()
                        // Add toolbar with a close button
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") {
                                    cleanupAndDismiss()
                                }
                            }
                        }
                }
                
                if showConfirmation {
                    confirmationOverlay
                }
            }
            .navigationBarBackButtonHidden(true)
            .alert("Upload Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .onDisappear {
            // Remove the editor from the view hierarchy so that its video stops playing
            isEditorActive = false
            cleanupAndDismiss()
        }
    }
    
    private var confirmationOverlay: some View {
        VStack {
            Spacer()
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else {
                HStack {
                    Button(action: {
                        print("🎬 [EDITOR] User confirmed edits")
                        if let url = editedVideoURL {
                            print("🎬 [EDITOR] Creating/updating project with video from: \(url.path)")
                            isUploading = true
                            Task {
                                do {
                                    if let project = existingProject {
                                        // Update existing project
                                        print("🎬 [EDITOR] Updating existing project: \(project.id)")
                                        await projectManager.updateProject(project, with: url)
                                    } else {
                                        // Create new project
                                        print("🎬 [EDITOR] Creating new project")
                                        await projectManager.createProject(with: url)
                                    }
                                    
                                    // Clean up the original video after successful upload
                                    cleanupOriginalVideo()
                                    
                                    // Switch to Projects tab (index 3) and dismiss all views
                                    selectedTab = 3
                                    // Dismiss all the way back to root
                                    dismiss()
                                    // Give time for the tab switch before dismissing
                                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                    
                                    // Refresh projects list
                                    await projectManager.loadProjects()
                                } catch {
                                    print("❌ [EDITOR] Upload error: \(error)")
                                    errorMessage = error.localizedDescription
                                    showError = true
                                    isUploading = false
                                }
                            }
                        }
                    }) {
                        Text(existingProject != nil ? "Save Changes" : "Confirm Edits")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    Button(action: {
                        print("🎬 [EDITOR] User discarded edits")
                        cleanupAndDismiss()
                    }) {
                        Text("Discard Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
    }
    
    private func cleanupAndDismiss() {
        // Clean up the video file
        cleanupOriginalVideo()
        // Dismiss the view
        dismiss()
    }
    
    private func cleanupOriginalVideo() {
        do {
            try FileManager.default.removeItem(at: video)
            print("🧹 [EDITOR] Cleaned up original video: \(video.path)")
        } catch {
            print("⚠️ [EDITOR] Could not clean up original video: \(error)")
        }
    }
} 