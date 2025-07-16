import SwiftUI

struct ServerDetailPlayersSection: View {
    let statusData: ServerStatus.StatusData

    var body: some View {
        SectionView {
            HStack {
                Label("Players", systemImage: "person.2.fill")
                    .font(.headline)

                Spacer()

                Group {
                    if let players = statusData.players {
                        Text("\(players.online) / \(players.max)")
                    } else {
                        Text(verbatim: "???")
                    }
                }
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            }
        } content: {
            VStack(spacing: 12) {
                if let players = statusData.players, let playerSample = players.sample, !playerSample.isEmpty {
                    LazyVStack(spacing: 12) {
                        ForEach(playerSample, id: \.id) { player in
                            PlayerItemView(player: player)
                        }
                    }

                    if players.online > players.sample?.count ?? 0 {
                        Text("and \(players.online - UInt32(playerSample.count)) more...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                } else if let players = statusData.players, players.online > 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("Player list not available")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("No players currently online")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }
} 
