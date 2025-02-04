import SwiftUI
import VideoEditorSDK

struct VideoEditorSwiftUIView: View {
    // The action to dismiss the view.
    internal var dismissAction: (() -> Void)?
    
    // The video being edited.
    let video: Video
    
    var body: some View {
        VideoEditor(video: video)
            .onDidSave { result in
                // The user exported a new video successfully and the newly generated video is located at `result.output.url`
                print("Received video at \(result.output.url.absoluteString)")
                dismissAction?()
            }
            .onDidCancel {
                // The user tapped on the cancel button within the editor
                dismissAction?()
            }
            .onDidFail { error in
                // There was an error generating the video
                print("Editor finished with error: \(error.localizedDescription)")
                dismissAction?()
            }
            .ignoresSafeArea()
    }
} 