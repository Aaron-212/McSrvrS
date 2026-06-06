import CachedAsyncImage
import SwiftUI

struct SectionView<Header: View, Content: View>: View {
    let header: Header
    let content: Content

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .padding(.vertical)
            content
        }
    }
}

struct MotdView: View {
    @Environment(\.colorScheme) var colorScheme

    let motd: AttributedString

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message of the Day")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(motd)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
                .colorScheme(.dark)
        }
        .padding(.bottom, 8)
    }
}

struct PlayerItemView: View {
    let player: ServerStatus.Player

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: player.avatarUrl) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image("Steve")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 32, height: 32)

            Text(player.name)
                .font(.callout)
                .fontWeight(.medium)
                .textSelection(.enabled)

            Spacer()
        }
    }
}
