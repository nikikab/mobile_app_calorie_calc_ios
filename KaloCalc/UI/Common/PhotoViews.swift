import SwiftUI

/// A diary photo as a small rounded square.
struct PhotoThumb: View {
    let name: String
    let photos: PhotoStore
    var size: CGFloat = 48
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(tr("photo_desc"))
        .task(id: name) {
            let target = Int(size * 3)
            image = await Task.detached { photos.load(name, maxPixel: target) }.value
        }
    }
}

/// A diary photo at full size.
struct PhotoFull: View {
    let name: String
    let photos: PhotoStore
    @State private var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image { Image(uiImage: image).resizable().scaledToFit() }
        }
        .onTapGesture { dismiss() }
        .accessibilityLabel(tr("photo_desc"))
        .task(id: name) { image = await Task.detached { photos.load(name, maxPixel: 1280) }.value }
    }
}

/// A photo that is still waiting to be saved with an entry (a file path, not a name).
struct PendingPhotoThumb: View {
    let path: String
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(tr("photo_desc"))
    }
}
