import TodoCLI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

// The whole executable: `CommandLine` is the standard library's, `ProcessInfo` is Foundation's and `exit` is
// libc's, which is why the imports outnumber the statement. Everything else is `TodoCLI`, so that the demo
// is tested the way the core is.
exit(CLI.main(CommandLine.arguments, environment: ProcessInfo.processInfo.environment))
