import Charts
import SwiftUI

enum QuerySpan: CaseIterable {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    case lastQuarter
    case lastYear  // all data

    var description: LocalizedStringResource {
        switch self {
        case .lastHour: return "Hour"
        case .lastDay: return "Day"
        case .lastWeek: return "Week"
        case .lastMonth: return "Month"
        case .lastQuarter: return "Quater"
        case .lastYear: return "Year"
        }
    }
}

struct PlayerCountDataPoint {
    let timestamp: Date
    let playerCount: Int?
}

struct ServerDetailPlayersChartSection: View {
    let server: Server
    @Binding var selectedSpan: QuerySpan
    @State private var hoverDate: Date? = nil

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
                        Text(span.description)
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

                                if hoverDate != nil, let dataPoint = nearestDataPoint(for: playerCountHistory) {
                                    RuleMark(
                                        x: .value("Time", dataPoint.timestamp)
                                    )
                                    .annotation {
                                        DataPointAnnotation(for: dataPoint)
                                    }

                                }
                            }
                        }
                        .frame(height: 240)
                        .chartXScale(
                            domain: max(
                                offsetDate(for: selectedSpan),
                                playerCountHistory.first?.timestamp ?? offsetDate(for: selectedSpan)
                            )...(playerCountHistory.last?.timestamp ?? Date())
                        )
                        .chartYScale(domain: 0...max(10, playerCountHistory.compactMap(\.playerCount).max() ?? 10))
                        #if os(macOS)
                            .chartOverlay { proxy in
                                Color.clear
                                .onContinuousHover { hoverPhas in
                                    switch hoverPhas {
                                    case .active(let location):
                                        hoverDate = proxy.value(atX: location.x, as: Date.self)
                                    case .ended:
                                        hoverDate = nil
                                    }
                                }
                            }
                        #else
                            .chartOverlay { proxy in
                                GeometryReader { _ in
                                    Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if let date: Date = proxy.value(
                                                    atX: value.location.x,
                                                    as: Date.self
                                                ) {
                                                    hoverDate = date
                                                } else {
                                                    hoverDate = nil
                                                }
                                            }
                                            .onEnded { _ in
                                                hoverDate = nil
                                            }
                                    )
                                }
                            }
                        #endif
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
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

    private func DataPointAnnotation(for dataPoint: PlayerCountDataPoint) -> some View {
        VStack(spacing: 4) {
            Text(dataPoint.timestamp.formatted(date: .numeric, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let playerCount = dataPoint.playerCount {
                Text("\(playerCount)")
                    .font(.headline)
            } else {
                Text("N/A")
                    .font(.headline)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func nearestDataPoint(for dataPoints: [PlayerCountDataPoint]) -> PlayerCountDataPoint? {
        guard let hoverDate else { return nil }
        guard !dataPoints.isEmpty else { return nil }

        // 3) Binary-search for the closest timestamp.
        var low = 0
        var high = dataPoints.count - 1

        while low <= high {
            let mid = (low + high) >> 1
            let midDate = dataPoints[mid].timestamp

            if midDate == hoverDate {  // exact hit
                return PlayerCountDataPoint(
                    timestamp: midDate,
                    playerCount: dataPoints[mid].playerCount
                )
            } else if midDate < hoverDate {  // look in the upper half
                low = mid + 1
            } else {  // look in the lower half
                high = mid - 1
            }
        }

        // 4) `low` is the first index whose date is > hoverDate
        //    `high` is the last index whose date is < hoverDate
        switch (high, low) {
        case (-1, _):  // hoverDate precedes the first point
            let dp = dataPoints[low]
            return PlayerCountDataPoint(
                timestamp: dp.timestamp,
                playerCount: dp.playerCount
            )

        case (_, let l) where l == dataPoints.count:  // hoverDate is after the last point
            let dp = dataPoints[high]
            return PlayerCountDataPoint(
                timestamp: dp.timestamp,
                playerCount: dp.playerCount
            )

        default:  // hoverDate lies between two points – pick the closest
            let before = dataPoints[high]
            let after = dataPoints[low]
            let nearest =
                abs(before.timestamp.timeIntervalSince(hoverDate)) < abs(after.timestamp.timeIntervalSince(hoverDate))
                ? before : after
            return PlayerCountDataPoint(
                timestamp: nearest.timestamp,
                playerCount: nearest.playerCount
            )
        }
    }

    private func offsetDate(for span: QuerySpan) -> Date {
        let now = Date()
        let calendar = Calendar.current

        switch span {
        case .lastHour:
            return calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        case .lastDay:
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .lastWeek:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastQuarter:
            return calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
    }

    private func getPlayerCountHistory(for span: QuerySpan) -> [PlayerCountDataPoint] {
        let startDate = offsetDate(for: span)

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
