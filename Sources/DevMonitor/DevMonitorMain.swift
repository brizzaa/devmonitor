#if !os(macOS)
import Foundation

@main
enum DevMonitorMain {
    static func main() {
        fputs("DevMonitor is a native macOS app (macOS 14 or later).\n", stderr)
        fputs("Open Package.swift in Xcode on a Mac and run the DevMonitor scheme.\n", stderr)
    }
}
#endif
