import SwiftUI
import VideoEditorSDK

struct VideoEditorSwiftUIView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedVideoURL: URL?
    @State private var showConfirmation = false
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @StateObject private var projectManager = ProjectManager()
    
    // The video being edited.
    let video: Video
    
    var body: some View {
        NavigationStack {
            ZStack {
                VideoEditor(video: video)
                    .onDidSave { result in
                        // The user exported a new video successfully
                        print("🎬 [EDITOR] Received edited video at \(result.output.url.absoluteString)")
                        editedVideoURL = result.output.url
                        showConfirmation = true
                    }
                    .onDidCancel {
                        print("🎬 [EDITOR] User cancelled editing")
                        dismiss()
                    }
                    .onDidFail { error in
                        print("🎬 [EDITOR] Error: \(error.localizedDescription)")
                        dismiss()
                    }
                    .ignoresSafeArea()
                
                if showConfirmation {
                    VStack {
                        Spacer()
                        if isUploading {
                            ProgressView("Uploading...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                        } else {
                            Button(action: {
                                print("🎬 [EDITOR] User confirmed edits")
                                if let url = editedVideoURL {
                                    print("🎬 [EDITOR] Creating project with video from: \(url.path)")
                                    isUploading = true
                                    Task {
                                        do {
                                            await projectManager.createProject(with: url)
                                            // Switch to Projects tab (index 3)
                                            selectedTab = 3
                                            dismiss()
                                        } catch {
                                            print("❌ [EDITOR] Upload error: \(error)")
                                            errorMessage = error.localizedDescription
                                            showError = true
                                            isUploading = false
                                        }
                                    }
                                }
                            }) {
                                Text("Confirm Edits")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .alert("Upload Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
} 