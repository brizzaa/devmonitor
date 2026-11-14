#if os(macOS)
import SwiftUI
import DevMonitorCore

enum Theme {
    static let bg = Color(red: 0.05, green: 0.055, blue: 0.075)
    static let cyan = Color(red: 0.25, green: 0.93, blue: 0.82)
    static let violet = Color(red: 0.55, green: 0.42, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.72, blue: 0.32)
    static let stroke = Color.white.opacity(0.10)
    static let quiet = Color.white.opacity(0.62)

    static var accent: LinearGradient {
        LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct StudioBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.cyan.opacity(0.20), .clear], center: .topLeading, startRadius: 10, endRadius: 560)
            RadialGradient(colors: [Theme.violet.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
    }
}

struct RingGauge: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: fraction)
        }
        .frame(width: 46, height: 46)
    }
}

struct Sparkline: View {
    var values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let series = values.count >= 2 ? values : [0, values.last ?? 0]
            let high = max(series.max() ?? 1, 0.1)
            let low = min(series.min() ?? 0, 0)
            let span = max(high - low, 0.1)
            Path { path in
                for (index, value) in series.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(series.count - 1, 1))
                    let y = geo.size.height - CGFloat((value - low) / span) * (geo.size.height - 2) - 1
                    let point = CGPoint(x: x, y: y)
                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 76, height: 22)
        .accessibilityLabel("CPU history")
    }
}

struct EmptyPanel: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(Theme.quiet)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

extension DevRuntime {
    var symbolName: String {
        switch self {
        case .node: return "server.rack"
        case .bun: return "hare"
        case .deno: return "d.square"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .ruby: return "diamond"
        case .java: return "cup.and.saucer"
        case .go: return "bolt"
        case .rust: return "gearshape.2"
        case .swift: return "swift"
        case .docker: return "shippingbox"
        case .postgres: return "cylinder.split.1x2"
        case .redis: return "square.stack.3d.up"
        case .mysql: return "cylinder"
        case .mongo: return "leaf"
        case .nginx: return "network"
        case .php: return "p.square"
        case .beam: return "atom"
        case .dotnet: return "square.grid.3x3.fill"
        case .kubernetes: return "square.3.layers.3d"
        case .unknown: return "circle"
        }
    }
}
#endif
