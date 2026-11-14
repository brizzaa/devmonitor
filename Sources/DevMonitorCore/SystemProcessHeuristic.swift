import Foundation

public struct SystemProcessHeuristic: Sendable {
    public init() {}

    /// Recognised dev runtimes are never treated as system processes, even when
    /// they run as root (Postgres, Docker). Shells under `/bin` stay visible:
    /// they are how a developer tells sessions apart.
    public func isSystem(_ process: ProcessRecord, runtime: DevRuntime) -> Bool {
        if runtime.isDeveloperFacing { return false }
        if process.name == "kernel_task" || process.name.hasPrefix("com.apple.") { return true }
        if systemNames.contains(process.name) { return true }
        let path = executablePath(process.command)
        if systemPrefixes.contains(where: { path.hasPrefix($0) }) { return true }
        return false
    }

    private func executablePath(_ command: String) -> String {
        command.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? command
    }

    private var systemPrefixes: [String] {
        ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/lib/", "/Library/Apple/"]
    }

    private var systemNames: Set<String> {
        [
            "kernel_task", "launchd", "syslogd", "WindowServer", "loginwindow",
            "distnoted", "cfprefsd", "notifyd", "opendirectoryd", "coreservicesd",
            "runningboardd", "logd", "UserEventAgent", "lsd", "trustd",
            "secd", "securityd", "mds", "mds_stores", "fseventsd", "coreaudiod",
            "bluetoothd", "airportd", "wifid", "configd", "powerd",
            "syspolicyd", "amfid", "sandboxd", "diskarbitrationd",
            "locationd", "symptomsd", "nsurlsessiond", "coreauthd",
            "ReportCrash", "watchdogd", "kernelmanagerd", "logind",
            "mDNSResponder", "apsd", "sharingd", "universalaccessd",
            "usernoted", "CommCenter", "identityservicesd", "cloudd",
            "containermanagerd", "pkd", "tccd", "controlcenter",
        ]
    }
}
