import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct FaviconView: View {
    let serverState: ServerStatus.StatusState

    var body: some View {
        serverState.faviconImage
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

extension ServerStatus.StatusState {
    var faviconImage: Image {
        guard case .success(let statusData) = self else {
            return .defaultServerFavicon
        }

        return statusData.faviconImage
    }

    var hasCustomFavicon: Bool {
        guard case .success(let statusData) = self else {
            return false
        }

        return statusData.decodedFaviconImage != nil
    }
}

extension ServerStatus.StatusData {
    var faviconImage: Image {
        decodedFaviconImage ?? .defaultServerFavicon
    }

    var decodedFaviconImage: Image? {
        Image(base64PNG: favicon)
    }
}

extension Server {
    var faviconImage: Image {
        currentState.faviconImage
    }

    var hasCustomFavicon: Bool {
        currentState.hasCustomFavicon
    }
}

extension Image {
    static var defaultServerFavicon: Image {
        Image("pack")
    }

    init?(base64PNG favicon: String?) {
        guard let favicon else {
            return nil
        }

        let cleaned = favicon.components(separatedBy: ",").last ?? favicon

        #if os(macOS)
            guard let data = Data(base64Encoded: cleaned),
                let nsImage = NSImage(data: data)
            else {
                return nil
            }

            self = Image(nsImage: nsImage)
        #elseif canImport(UIKit)
            guard let data = Data(base64Encoded: cleaned),
                let uiImage = UIImage(data: data)
            else {
                return nil
            }

            self = Image(uiImage: uiImage)
        #else
            return nil
        #endif
    }
}

extension ServerStatus.StatusData {
    var faviconView: some View {
        FaviconView(serverState: .success(self))
    }
}

extension Server {
    var faviconView: some View {
        FaviconView(serverState: currentState)
    }
}
