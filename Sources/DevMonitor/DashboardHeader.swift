#if os(macOS)
import Charts
import SwiftUI
import DevMonitorCore

struct DashboardHeader: View {
    var stats: DashboardStats
    var cpuHistory: [Double]
    var memoryHistory: [Double]
    var totals: [ProjectResourceTotal]
    var onSelectProject: (ProjectResourceTotal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEV MONITOR")
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.accent)
                    Text("Local control room")
                        .font(.title2.weight(.semibold))
                }
                Spacer(minLength: 8)
                pulseCard(
                    title: "Dev CPU",
                    value: String(format: "%.0f%%", stats.developerCPU),
                    fraction: stats.developerCPU / 100,
                    tint: Theme.cyan,
                    series: cpuHistory
                )
                pulseCard(
                    title: "Dev memory",
                    value: ByteFormat.string(bytes: stats.developerMemory),
                    fraction: min(Double(stats.developerMemory) / Double(8 * 1024 * 1024 * 1024), 1),
                    tint: Theme.violet,
                    series: memoryHistory
                )
                pulseCard(
                    title: "Ports",
                    value: "\(stats.listeningPortCount)",
                    fraction: min(Double(stats.listeningPortCount) / 20, 1),
                    tint: Theme.amber,
                    series: []
                )
            }
            if !totals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(totals) { total in
                            Button {
                                onSelectProject(total)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(total.name)
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)
                                    Text(String(format: "%.0f%%", total.cpuPercent))
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(Theme.cyan)
                                    Text(ByteFormat.string(bytes: total.memoryBytes))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.quiet)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("\(total.processCount) processes · \(total.listeningPortCount) ports")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func pulseCard(title: String, value: String, fraction: Double, tint: Color, series: [Double]) -> some View {
        HStack(spacing: 10) {
            RingGauge(fraction: fraction, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.quiet)
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                if series.count >= 2 {
                    Chart {
                        ForEach(Array(series.enumerated()), id: \.offset) { item in
                            AreaMark(
                                x: .value("Sample", item.offset),
                                y: .value("Value", item.element)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [tint.opacity(0.45), tint.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Sample", item.offset),
                                y: .value("Value", item.element)
                            )
                            .foregroundStyle(tint)
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .frame(width: 120, height: 28)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
#endif
