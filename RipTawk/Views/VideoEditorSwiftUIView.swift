import SwiftUI
import VideoEditorSDK
import AVFoundation
import UIKit

// Helper extension for replacing default icons with custom icons
private extension UIImage {
    func icon(pt: CGFloat, alpha: CGFloat = 1) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: pt, height: pt), false, scale)
        let position = CGPoint(x: (pt - size.width) / 2, y: (pt - size.height) / 2)
        draw(at: position, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

// Setup custom icons for the editor
private func setupCustomIcons() {
    let config = UIImage.SymbolConfiguration(scale: .large)
    
    IMGLY.bundleImageBlock = { imageName in
        switch imageName {
        case "imgly_icon_cancel":
            return UIImage(systemName: "multiply.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
        case "imgly_icon_approve_44pt":
            return UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
        case "imgly_icon_save":
            return UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)?.icon(pt: 44, alpha: 0.6)
        case "imgly_icon_undo_48pt":
            return UIImage(systemName: "arrow.uturn.backward", withConfiguration: config)?.icon(pt: 48)
        case "imgly_icon_redo_48pt":
            return UIImage(systemName: "arrow.uturn.forward", withConfiguration: config)?.icon(pt: 48)
        case "imgly_icon_play_48pt":
            return UIImage(systemName: "play.fill", withConfiguration: config)?.icon(pt: 48)
        case "imgly_icon_pause_48pt":
            return UIImage(systemName: "pause.fill", withConfiguration: config)?.icon(pt: 48)
        case "imgly_icon_sound_on_48pt":
            return UIImage(systemName: "speaker.wave.2.fill", withConfiguration: config)?.icon(pt: 48)
        case "imgly_icon_sound_off_48pt":
            return UIImage(systemName: "speaker.slash.fill", withConfiguration: config)?.icon(pt: 48)
        default:
            return nil
        }
    }
}

// UIViewControllerRepresentable wrapper for VideoEditViewController
struct VideoEditorWrapper: UIViewControllerRepresentable {
    let video: URL
    var onSave: (VideoEditorResult) -> Void
    var onCancel: () -> Void
    var onError: (VideoEditorError) -> Void
    
    func makeUIViewController(context: Context) -> VideoEditViewController {
        let configuration = Configuration { builder in
            builder.configureVideoEditViewController { options in
                // Configure the available tool menu items
                options.menuItems = [
                    ToolMenuItem.createFilterToolItem(),
                    ToolMenuItem.createAdjustToolItem(),
                    ToolMenuItem.createTransformToolItem(),
                    ToolMenuItem.createCompositionOrTrimToolItem(),
                    ToolMenuItem.createAudioToolItem(),
                    ToolMenuItem.createFocusToolItem(),
                    ToolMenuItem.createStickerToolItem(),
                    ToolMenuItem.createTextToolItem(),
                    ToolMenuItem.createTextDesignToolItem(),
                    ToolMenuItem.createOverlayToolItem(),
                    ToolMenuItem.createFrameToolItem(),
                    ToolMenuItem.createBrushToolItem()
                ].compactMap { $0 }.map { .tool($0) }
            }
        }
        
        let editor = VideoEditViewController(videoAsset: ImglyKit.Video(url: video), configuration: configuration)
        editor.delegate = context.coordinator
        editor.modalPresentationStyle = .fullScreen
        return editor
    }
    
    func updateUIViewController(_ uiViewController: VideoEditViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VideoEditViewControllerDelegate {
        let parent: VideoEditorWrapper
        
        init(_ parent: VideoEditorWrapper) {
            self.parent = parent
        }
        
        func videoEditViewControllerShouldStart(_ videoEditViewController: VideoEditViewController, task: VideoEditorTask) -> Bool {
            true
        }
        
        func videoEditViewControllerDidFinish(_ videoEditViewController: VideoEditViewController, result: VideoEditorResult) {
            parent.onSave(result)
        }
        
        func videoEditViewControllerDidFail(_ videoEditViewController: VideoEditViewController, error: VideoEditorError) {
            parent.onError(error)
        }
        
        func videoEditViewControllerDidCancel(_ videoEditViewController: VideoEditViewController) {
            parent.onCancel()
        }
    }
}

struct VideoEditorSwiftUIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedVideoURL: URL?
    @State private var showConfirmation = false
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @StateObject private var projectManager = ProjectManager()
    
    let video: URL
    var existingProject: VideoProject?
    
    init(video url: URL, existingProject: VideoProject? = nil) {
        self.video = url
        self.existingProject = existingProject
        setupCustomIcons() // Setup custom icons when initializing
    }
    
    var body: some View {
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
            .alert("Upload Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showConfirmation) {
                confirmationOverlay
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