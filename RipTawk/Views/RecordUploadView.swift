//
//  RecordUploadView.swift
//  RipTawk
//
//  Created by Zahad Ali Syed on 2/3/25.
//

import SwiftUI
import AVFoundation

struct RecordUploadView: View {
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showEditingTools = false
    @State private var recordedVideoURL: URL?

    var body: some View {
        VStack {
            if let videoURL = recordedVideoURL {
                // Show video preview or editing options
                Text("Video recorded at: \(videoURL.absoluteString)")
            } else {
                CameraView(recordedVideoURL: $recordedVideoURL)
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var recordedVideoURL: URL?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.recordedVideoURL = videoURL
            }
            picker.dismiss(animated: true)
        }
    }
}

struct PhotoLibraryView: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryView
        
        init(_ parent: PhotoLibraryView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.selectedVideoURL = videoURL
            }
            picker.dismiss(animated: true)
        }
    }
}

