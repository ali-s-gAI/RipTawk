import Foundation

struct VideoProject: Identifiable {
    let id = UUID()
    let title: String
    let thumbnail: String
    let duration: TimeInterval
    let videoURL: URL
    
    static var sampleProjects: [VideoProject] = [
        VideoProject(
            title: "My First Video",
            thumbnail: "thumbnail1",
            duration: 60.0,
            videoURL: URL(string: "https://example.com/video1")!
        )
    ]
}

struct VideoFilter: Identifiable {
    let id = UUID()
    let name: String
    let intensity: Double
}

struct TextOverlay: Identifiable {
    let id = UUID()
    var text: String
    var position: TextPosition
    var fontSize: CGFloat
    
    enum TextPosition {
        case topLeft, topRight, center, bottomLeft, bottomRight
    }
} 