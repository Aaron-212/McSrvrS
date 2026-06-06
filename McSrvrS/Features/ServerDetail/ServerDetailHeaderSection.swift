import SwiftUI

struct ServerDetailHeaderSection: View {
    let server: Server

    var body: some View {
        VStack {
            server.faviconView
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            VStack(spacing: 4) {
                Text(server.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(server.addressDescription)
                    .font(.subheadline)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical)
    }
}
