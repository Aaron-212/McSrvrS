import SwiftUI

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct FaviconView: View {
    let serverState: Server.ServerState

    var body: some View {
        switch serverState {
        case .success(let status):
            if let image = decodeBase64PNG(from: status.favicon) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "globe")
                    .foregroundColor(.secondary)
            }
        case .error, .loading:
            Image("pack")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    private func decodeBase64PNG(from favicon: String?) -> Image? {
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

// Convenience extension for Server.Status
extension Server.Status {
    var faviconView: some View {
        FaviconView(serverState: .success(self))
    }
}

// Convenience extension for Server
extension Server {
    var faviconView: some View {
        FaviconView(serverState: self.serverState)
    }
}
