import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct FaviconView: View {
    let serverState: ServerStatus.StatusState

    var body: some View {
        if case .success(let statusData) = serverState,
            let image = decodeBase64PNG(from: statusData.favicon)
        {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image("pack")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    func decodeBase64PNG(from favicon: String?) -> Image? {
        guard let favicon = favicon else { return nil }

        let cleaned = favicon.components(separatedBy: ",").last ?? favicon

        #if os(macOS)
            guard let data = Data(base64Encoded: cleaned),
                let nsImage = NSImage(data: data)
            else { return nil }

            return Image(nsImage: nsImage)
        #else
            guard let data = Data(base64Encoded: cleaned),
                let uiImage = UIImage(data: data)
            else { return nil }

            return Image(uiImage: uiImage)
        #endif
    }
}

// Convenience extension for ServerStatus.StatusData
extension ServerStatus.StatusData {
    var faviconView: some View {
        FaviconView(serverState: .success(self))
    }
}

// Convenience extension for Server
extension Server {
    var faviconView: some View {
        FaviconView(serverState: self.currentState)
    }
}
