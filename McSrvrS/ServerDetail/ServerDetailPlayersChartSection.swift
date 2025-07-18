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
    @State private var lastIndex: Int = 0

    var body: some View {
        let playerCountHistory = getPlayerCountHistory(for: selectedSpan)
        let hasData = playerCountHistory.contains { $0.playerCount != nil }
        let domain = domain(for: playerCountHistory)
        let average = averagePlayerCount(hasData, for: playerCountHistory, between: domain)

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

                HStack {
                    VStack(alignment: .leading) {
                        Text("Average Player Count")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Group {
                            if let average {
                                Text(average, format: .number)
                            } else {
                                Text("N/A")
                            }
                        }
                        .font(.title2)
                        .bold()
                        Text(domain.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .opacity(hoverDate != nil ? 0 : 1)
                    .transition(.opacity)

                    Spacer()
                }

                Group {
                    if hasData {
                        Chart(playerCountHistory, id: \.timestamp) { dataPoint in
                            if hoverDate != nil, let dataPoint = nearestDataPoint(for: playerCountHistory) {
                                RuleMark(
                                    x: .value("Time", dataPoint.timestamp)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1))
                                .foregroundStyle(.gray.opacity(0.5))
                                .annotation(
                                    spacing: 11,
                                    overflowResolution: .init(x: .fit, y: .disabled)
                                ) {
                                    DataPointAnnotation(for: dataPoint)
                                }
                            }

                            if let playerCount = dataPoint.playerCount {
                                LineMark(
                                    x: .value("Time", dataPoint.timestamp),
                                    y: .value("Player Count", playerCount)
                                )

                                AreaMark(
                                    x: .value("Time", dataPoint.timestamp),
                                    y: .value("Player Count", playerCount),
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
                        .chartXScale(domain: domain)
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

    private func domain(for playerCountHistory: [PlayerCountDataPoint]) -> ClosedRange<Date> {
        return max(
            offsetDate(for: selectedSpan),
            playerCountHistory.first?.timestamp ?? offsetDate(for: selectedSpan)
        )...(playerCountHistory.last?.timestamp ?? Date())
    }

    private func DataPointAnnotation(for dataPoint: PlayerCountDataPoint) -> some View {
        VStack(alignment: .leading) {
            Text("Player Count")
                .font(.caption)
                .foregroundStyle(.secondary)
            Group {
                if let playerCount = dataPoint.playerCount {
                    Text(playerCount, format: .number)
                } else {
                    Text("N/A")
                }
            }
            .font(.title2)
            .bold()
            Text(dataPoint.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func nearestDataPoint(for dataPoints: [PlayerCountDataPoint]) -> PlayerCountDataPoint? {
        guard let hoverDate else { return nil }
        guard !dataPoints.isEmpty else { return nil }

        var lo = 0
        var hi = dataPoints.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if dataPoints[mid].timestamp < hoverDate {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        if lo == 0 {
            return dataPoints.first
        }
        if lo == dataPoints.count {
            return dataPoints.last
        }

        let prev = dataPoints[lo - 1]
        let next = dataPoints[lo]

        let diffPrev = abs(prev.timestamp.timeIntervalSince(hoverDate))
        let diffNext = abs(next.timestamp.timeIntervalSince(hoverDate))

        return diffPrev <= diffNext ? prev : next
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

    private func averagePlayerCount(
        _ hasData: Bool,
        for dataPoints: [PlayerCountDataPoint],
        between span: ClosedRange<Date>
    ) -> Int? {
        guard hasData else { return nil }

        let validCounts = dataPoints
            .filter { span.contains($0.timestamp) }
            .compactMap(\.playerCount)

        guard !validCounts.isEmpty else { return nil }

        let total = validCounts.reduce(0, +)
        return total / validCounts.count
    }
}

extension ClosedRange<Date> {
    fileprivate var description: LocalizedStringResource {
        if Calendar.current.isDate(self.lowerBound, equalTo: self.upperBound, toGranularity: .day) {
            return
                "\(self.lowerBound.formatted(date: .omitted, time: .standard)) to \(self.upperBound.formatted(date: .omitted, time: .standard))"
        } else {
            return
                "\(self.lowerBound.formatted(date: .abbreviated, time: .omitted)) to \(self.upperBound.formatted(date: .abbreviated, time: .omitted))"
        }

    }
}
