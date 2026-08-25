import AppKit
import StatusLensCore

@main
@MainActor
enum Main {
    /// Held strongly because `NSApplication.delegate` is a weak reference.
    static var delegate: AppDelegate?

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first {
            switch command {
            case "version", "--version", "-v":
                print(appVersion)
                exit(0)
            case "help", "--help", "-h":
                printUsage()
                exit(0)
            default:
                FileHandle.standardError.write(Data("status-lens: unknown argument '\(command)'\n".utf8))
                printUsage()
                exit(2)
            }
        }

        // Two instances would stack two menu bar items and double-poll.
        // LSMultipleInstancesProhibited (Info.plist) stops LaunchServices
        // launches; this guard stops the rest (direct exec, `open -n`).
        let bundleID = Bundle.main.bundleIdentifier
        let instancePIDs = bundleID.map { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .map(\.processIdentifier)
        } ?? []
        if case .exitDuplicate(let message) = singleInstanceDecision(
            bundleID: bundleID,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            instancePIDs: instancePIDs
        ) {
            FileHandle.standardError.write(Data((message + "\n").utf8))
            exit(0)
        }

        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

func printUsage() {
    print("""
    status-lens — menu bar service status watcher for Statuspage-hosted pages

    Usage:
      status-lens             Launch the menu bar app
      status-lens --version   Print the version
      status-lens --help      Show this help
    """)
}
