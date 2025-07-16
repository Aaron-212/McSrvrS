import Charts
import SwiftUI

enum QuerySpan: String, CaseIterable {
    case today = "Today"
    case last7Days = "7 Days"
    case last30Days = "30 Days"
    case lastQuarter = "Quarter"
    case lastYear = "Year"  // all data
}

struct PlayerCountDataPoint {
    let timestamp: Date
    let playerCount: Int?
}

struct ServerDetailPlayersChartSection: View {
    let server: Server
    @Binding var selectedSpan: QuerySpan

    var body: some View {
        let playerCountHistory = getPlayerCountHistory(for: selectedSpan)
        let hasData = playerCountHistory.contains { $0.playerCount != nil }

        SectionView {
            HStack {
                Label("Player Count History", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)

                Spacer()
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Select Span", selection: $selectedSpan) {
                    ForEach(QuerySpan.allCases, id: \.self) { span in
                        Text(span.rawValue)
                            .tag(span)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Group {
                    if hasData {
                        Chart(playerCountHistory, id: \.timestamp) { dataPoint in
                            if let playerCount = dataPoint.playerCount {
                                LineMark(
                                    x: .value("Time", dataPoint.timestamp),
                                    y: .value("Players", playerCount)
                                )

                                AreaMark(
                                    x: .value("Time", dataPoint.timestamp),
                                    y: .value("Players", playerCount),
                                    series: .value("Players", "P")
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(
                                            colors: [
                                                .accent.opacity(0.5),
                                                .accent.opacity(0.2),
                                                .accent.opacity(0.0),
                                            ]
                                        ),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                        .frame(height: 240)
                        .chartYScale(domain: 0...max(10, playerCountHistory.compactMap(\.playerCount).max() ?? 10))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text("No player count data available")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity)

            }
        }
        .padding()
    }

    private func getPlayerCountHistory(for span: QuerySpan) -> [PlayerCountDataPoint] {
        let now = Date()
        let calendar = Calendar.current

        // Determine the start date based on the selected span
        let startDate: Date
        switch span {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .last7Days:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .last30Days:
            startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .lastQuarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .lastYear:
            // Return all data - use a very old date or no filtering
            startDate = Date.distantPast
        }

        let allStatuses = server.statuses
            .filter { $0.timestamp >= startDate }  // Filter by date range
            .sorted { $0.timestamp < $1.timestamp }

        return allStatuses.map { status in
            let playerCount: Int?

            if let statusData = status.statusData,
                let players = statusData.players
            {
                playerCount = Int(players.online)
            } else {
                // Failed status - pass nil to show gap in chart
                playerCount = nil
            }

            return PlayerCountDataPoint(
                timestamp: status.timestamp,
                playerCount: playerCount
            )
        }
    }
}
