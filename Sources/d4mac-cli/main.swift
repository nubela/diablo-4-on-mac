import D4MacCore
import Foundation

// d4mac — command-line front end to D4MacCore (same code as the app).

let usage = """
usage: d4mac <command> [--data-root DIR] [--d3dmetal FILE.dmg|DIR] [--hud] [--debug]

commands:
  status              show which setup steps are done
  setup [STEP...]     run setup steps that are not done (or only the named steps)
  battlenet           open Battle.net
  play                open Battle.net and start Diablo IV
  stop                stop all Windows programs
  env                 print the Wine environment (for manual testing)
"""

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return value
}
func flag(_ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}

let paths = option("--data-root").map { Paths(root: URL(fileURLWithPath: $0)) } ?? Paths()
let context = SetupContext(paths: paths, d3dmetalSource: option("--d3dmetal").map { URL(fileURLWithPath: $0) })
let options = LaunchOptions(metalHUD: flag("--hud"), debugLog: flag("--debug"))
guard let command = args.first else { print(usage); exit(2) }
let names = Array(args.dropFirst())

do {
    switch command {
    case "status":
        for step in Setup.steps {
            print("\(step.isDone(context) ? "✓" : "·") \(step.id.padding(toLength: 10, withPad: " ", startingAt: 0)) \(step.title)")
        }
        print("running: \(await Launcher(paths: paths).state())")
    case "setup":
        for step in Setup.steps where names.isEmpty ? !step.isDone(context) : names.contains(step.id) {
            print("==> \(step.title)")
            do {
                try await step.run(context) { p in
                    let pct = p.fraction.map { String(format: "%3.0f%% ", $0 * 100) } ?? "     "
                    print("    \(pct)\(p.message)")
                }
            } catch where !step.blocksLaterSteps {
                print("    skipped: \(error.localizedDescription)")
            }
        }
        print(Setup.isReady(context) ? "Setup complete." : "Some steps are still not done; run `d4mac status`.")
    case "battlenet", "play":
        let log = try await Launcher(paths: paths).start(playDiablo: command == "play", options: options)
        print("Started. Log: \(log.path)")
    case "stop":
        await Launcher(paths: paths).stop()
    case "env":
        let env = WineEnvironment.make(paths, options: options, base: [:])
        for key in env.keys.sorted() { print("export \(key)=\"\(env[key]!)\"") }
        print("export PATH=\"\(paths.wine.appendingPathComponent("bin").path):$PATH\"")
    default:
        print(usage); exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
