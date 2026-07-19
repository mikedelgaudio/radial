import Foundation

public enum LaunchPlan: Equatable {
    case application(appURL: URL, arguments: [String])
    case script(executable: String, arguments: [String])
    case openURL(URL)
    case openFolder(URL)
    case failure(String)
}

public protocol ProcessRunning {
    func run(executable: String, arguments: [String]) throws
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}
    public func run(executable: String, arguments: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        try p.run()   // detached; do not wait
    }
}
