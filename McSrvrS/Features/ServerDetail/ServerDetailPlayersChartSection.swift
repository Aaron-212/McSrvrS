import Charts
import SwiftUI

enum PlayerHistorySpan: CaseIterable {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    case lastQuarter
    case lastYear

    var title: LocalizedStringResource {
        switch self {
        case .lastHour: return "Hour"
        case .lastDay: return "Day"
        case .lastWeek: return "Week"
        case .lastMonth: return "Month"
        case .lastQuarter: return "Quarter"
        case .lastYear: return "Year"
        }
    }
}

struct PlayerCountSample {
    let timestamp: Date
    let playerCount: Int?
}

struct PlayerCountHistorySnapshot {
    let samples: [PlayerCountSample]
    let hasData: Bool
    let domain: ClosedRange<Date>
    let average: Int?

    init(
        server: Server,
        span: PlayerHistorySpan,
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        let startDate = Self.offsetDate(for: span, calendar: calendar, now: now)
        let samples = server.statuses
            .filter { $0.timestamp >= startDate }
            .sorted { $0.timestamp < $1.timestamp }
            .map { status in
                PlayerCountSample(
                    timestamp: status.timestamp,
                    playerCount: status.statusData?.players.map { Int($0.online) }
                )
            }
        let lowerBound = max(startDate, samples.first?.timestamp ?? startDate)
        let upperBound = samples.last?.timestamp ?? now
        let domain = lowerBound...upperBound
        let hasData = samples.contains { $0.playerCount != nil }

        self.samples = samples
        self.hasData = hasData
        self.domain = domain
        self.average = Self.averagePlayerCount(hasData, for: samples, between: domain)
    }

    private static func offsetDate(for span: PlayerHistorySpan, calendar: Calendar, now: Date) -> Date {
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

    private static func averagePlayerCount(
        _ hasData: Bool,
        for dataPoints: [PlayerCountSample],
        between span: ClosedRange<Date>
    ) -> Int? {
        guard hasData else { return nil }

        let validCounts =
            dataPoints
            .filter { span.contains($0.timestamp) }
            .compactMap(\.playerCount)

        guard !validCounts.isEmpty else { return nil }

        let total = validCounts.reduce(0, +)
        return total / validCounts.count
    }
}

struct ServerDetailPlayersChartSection: View {
    let server: Server
    @Binding var selectedSpan: PlayerHistorySpan
    @State private var isInspectingChart: Bool = false
    @State private var inspectedDate: Date = .now

    var body: some View {
        let snapshot = PlayerCountHistorySnapshot(server: server, span: selectedSpan)

        SectionView {
            HStack {
                Label("Player Count History", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)

                Spacer()
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Select Span", selection: $selectedSpan) {
                    ForEach(PlayerHistorySpan.allCases, id: \.self) { span in
                        Text(span.title)
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
                            if let average = snapshot.average {
                                Text(average, format: .number)
                            } else {
                                Text(verbatim: "N/A")
                            }
                        }
                        .font(.title)
                        .bold()
                        Text(snapshot.domain.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .opacity(isInspectingChart ? 0 : 1)
                    .transition(.opacity)

                    Spacer()
                }

                Group {
                    if snapshot.hasData {
                        Chart {
                            if isInspectingChart, let dataPoint = nearestDataPoint(for: snapshot.samples) {
                                RuleMark(
                                    x: .value("Time", dataPoint.timestamp)
                                )
                                .foregroundStyle(.gray.secondary)
                                .annotation(
                                    spacing: 11,
                                    overflowResolution: .init(x: .fit, y: .disabled)
                                ) {
                                    dataPointAnnotation(for: dataPoint)
                                }
                            }

                            ForEach(snapshot.samples, id: \.timestamp) { dataPoint in
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
                        }
                        .frame(height: 240)
                        .chartXScale(domain: snapshot.domain)
                        .chartYScale(domain: 0...max(10, snapshot.samples.compactMap(\.playerCount).max() ?? 10))
                        #if os(macOS)
                            .chartOverlay { proxy in
                                Color.clear
                                .onContinuousHover { hoverPhase in
                                    switch hoverPhase {
                                    case .active(let location):
                                        if let date: Date = proxy.value(atX: location.x, as: Date.self) {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                isInspectingChart = true
                                            }
                                            inspectedDate = date
                                        }
                                    case .ended:
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            isInspectingChart = false
                                        }
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
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        isInspectingChart = true
                                                    }
                                                    inspectedDate = date
                                                }
                                            }
                                            .onEnded { _ in
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    isInspectingChart = false
                                                }
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

    private func dataPointAnnotation(for dataPoint: PlayerCountSample) -> some View {
        VStack(alignment: .leading) {
            Text("Player Count")
                .font(.caption)
                .foregroundStyle(.secondary)
            Group {
                if let playerCount = dataPoint.playerCount {
                    Text(playerCount, format: .number)
                } else {
                    Text(verbatim: "N/A")
                }
            }
            .font(.title)
            .bold()
            Text(dataPoint.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func nearestDataPoint(for dataPoints: [PlayerCountSample]) -> PlayerCountSample? {
        guard !dataPoints.isEmpty else { return nil }

        var lo = 0
        var hi = dataPoints.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if dataPoints[mid].timestamp < inspectedDate {
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

        let diffPrev = abs(prev.timestamp.timeIntervalSince(inspectedDate))
        let diffNext = abs(next.timestamp.timeIntervalSince(inspectedDate))

        return diffPrev <= diffNext ? prev : next
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
