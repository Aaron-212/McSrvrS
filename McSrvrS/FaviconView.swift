import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Server.Status {
    public var decodeBase64PNG: Image? {
        guard let favicon = favicon else { return nil }

        let cleaned = favicon.components(separatedBy: ",").last ?? favicon

        #if os(iOS)
        guard let data = Data(base64Encoded: cleaned),
            let uiImage = UIImage(data: data)
        else { return nil }

        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let data = Data(base64Encoded: cleaned),
                let nsImage = NSImage(data: data)
        else { return nil }

        return Image(nsImage: nsImage)
        #endif
    }
}
