import Foundation
import SwiftCLI

public final class Tipsy {
    private let arguments: [String]
    
    public init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }
    
    public func run() throws {
        let version = "0.0.6"
        let tipsy = CLI(name: "tipsy", version: version)
        tipsy.commands = [RunCommand()]
        _ = tipsy.go()
    }
}
    
