import Foundation
import IPCProtocol

// `--selftest` runs an in-process XPC round-trip against a temp file, with no
// launchd/root/system changes — it verifies the IPC + removal path safely.
if CommandLine.arguments.contains("--selftest") {
    SelfTest.run()
    exit(0)
}

// `--local` installs (see Scripts/install-helper-local.sh) can't match an
// ad-hoc signature, so the code-signing pin is skipped. Signed/SMAppService
// installs omit the flag and keep the pin enforced.
let enforce = !CommandLine.arguments.contains("--local")

// Normal mode: run as the launchd-managed (root) Mach service.
let delegate = HelperListenerDelegate(enforceRequirement: enforce)
let listener = NSXPCListener(machServiceName: IPC.machServiceName)
listener.delegate = delegate
listener.resume()
dispatchMain()
