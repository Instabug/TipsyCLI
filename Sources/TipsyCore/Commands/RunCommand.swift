import SwiftCLI
import xcodeproj
import PathKit
import SwiftShell
import Foundation

class RunCommand: Command {
    let name = "run"
    let shortDescription = "Start a Tipsy run."
    
    // Required arguments
    //
    // Arguments are implemented as flags for a better interface.
    // See:
    // 1. https://medium.com/@jdxcode/12-factor-cli-apps-dd3c227a0e46
    // 2. https://softwareengineering.stackexchange.com/questions/307467/
    let workspace = Key<String>("-w", "--workspace", description: "[REQUIRED] Path to .xcworkspace file.")
    let project = Key<String>("-p", "--project", description: "[REQUIRED] Path to .xcodeproj file.")
    let target = Key<String>("-t", "--target", description: "[REQUIRED] Name of target that contains ScenarioProvider classes.")
    let scenarios = Key<String>("-s", "--scenarios", description: "[REQUIRED] Name of ScenarioProvider subclasses to run.")
    let destination = Key<String>("-u", "--destination", description: "[REQUIRED] A destination to run Tipsy on. Follows the same format of xcodebuild's -destination paramater.")
    
    // Run modes
    let time = Key<Int>("-d", "--time", description: "Time in minutes to keep running Tipsy for.")
    let comprehensive = Flag("-c", "--comprehensive", description: "Do a comprehensive run.")
    let replay = Key<String>("-r", "--replay", description: "Replays a previous run of Tipsy. Pass path to a replay file generated by a previous run.")
    let replayFileOutputPath = Key<String>("-o", "--replayfile-output-path", description: "Path to save replay file generated by the run.")
    
    // Resetting simulator between runs
    let reset = Flag("-x", "--reset", description: "Reset simulator before starting the run.")
    let uninstall = Key<String>("-u", "--uninstall", description: "App bundle identifier to uninstall before starting the run.")
    
    // Other options
    let preRun = Key<String>("-n", "--pre-run", description: "Reference to a closure of type () -> Void to be executed before any actions are run.")
    
    var optionGroups: [OptionGroup] {
        let runMode: OptionGroup = .atMostOne(time, comprehensive, replay)
        let resetOptions: OptionGroup = .atMostOne(reset, uninstall)
        
        return [runMode, resetOptions]
    }
    
    let autogeneratedXcodeGroupName = "Tipsy Autogenerated"
    let entryPointClassName = "Tipsy_EntryPoint"
    
    func execute() throws {
        guard let workspace = workspace.value else {
           throw CLI.Error(message: "Please provide path to .xcworkspace file using --workspace.")
        }
        
        guard let project = project.value else {
            throw CLI.Error(message: "Please provide path .xcodeproj file using --project.")
        }
        
        guard let target = target.value else {
            throw CLI.Error(message: "Please provide a target name using --target.")
        }
        
        guard  let scenarios = scenarios.value else {
            throw CLI.Error(message: "Please provide scenarios to run using --scenarios.")
        }
        
        guard let destination = destination.value else {
            throw CLI.Error(message: "Please provide a destination to run on using --destination.")
        }
        
        if let bundleIdentifier = uninstall.value {
            uninstallAppWith(bundleIdentifier: bundleIdentifier)
        }
        
        if reset.value {
            resetSimulator()
        }
        
        guard let entryPointPath =  createEntryPoint(workspace: workspace,
                                                     project: project,
                                                     target: target,
                                                     scenarios: scenarios) else {
            print("Failed to generated entry point.")
            return
        }

        let tempWorkspaceName = tempNameFrom(fileName: workspace)
        let tempProjectName = tempNameFrom(fileName: project)
        
        startTipsyRun(workspaceName: tempWorkspaceName,
                      targetName: target,
                      entryPointName: entryPointClassName,
                      destination: destination)
        
        cleanUpTempFiles(workspacePath: Path(tempWorkspaceName),
                         projectPath: Path(tempProjectName),
                         entryPointPath: Path(entryPointPath))
    }
}

// MARK: Helpers

extension RunCommand {
    
    func formattedDate() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy hh:mm a"
        return formatter.string(from: date)
    }
}

// MARK: Simulator

extension RunCommand {
    
    func resetSimulator() {
        print("Shutting down simulator.")
        var output = main.run(bash: "killall Simulator")
        
        if let _ = output.error {
            print("Failed to shutdown simulator.")
            return
        }
        
        print("Resetting simulator.")
        output = main.run(bash: "xcrun simctl erase all")
        
        if let _ = output.error {
            print("Failed to reset simulator.")
            return
        }
        
        print("Reset simulator.")
    }
    
    func uninstallAppWith(bundleIdentifier: String) {
        print("Uninstalling app with bundle identifier \(bundleIdentifier)")
        
        let output = main.run(bash: "xcrun simctl uninstall booted \(bundleIdentifier)")
        
        if let _ = output.error {
            print("Failed to uninstall app.")
        }
        
        print("Uninstalled app.")
        
    }
}

// MARK: Xcode Build

extension RunCommand {
    
    func startTipsyRun(workspaceName: String, targetName: String, entryPointName: String, destination: String) {
        print("Checking if simulator is running.")
        let output = main.run(bash: "killall -d Simulator")
        
        if output.exitcode == 1 {
            print("Starting simulator app.")
            main.run(bash: "open -a Simulator.app")
            
            print("Waiting for simulator to boot.")
            sleep(25)
        }
        
        print("Started run.")
        
        var testCommand = ""
        if isXcprettyAvailable() {
            testCommand = "set -o pipefail && xcodebuild -workspace \(workspaceName) -scheme \(targetName) -sdk iphonesimulator -destination '\(destination)' -only-testing:\(targetName)/\(entryPointName) test | xcpretty"
        } else {
            testCommand = "xcodebuild -workspace \(workspaceName) -scheme \(targetName) -sdk iphonesimulator -destination '\(destination)' -only-testing:\(targetName)/\(entryPointName) test"
        }
        
        do {
            try main.runAndPrint(bash: testCommand)
        } catch CommandError.returnedErrorCode(_, let errorCode) {
            exit(errormessage: "Tipsy run has failed", errorcode: errorCode)
        } catch {
            print("Something went wrong while trying to run test command.")
            exit(1)
        }
        
        print("Finished run.")
    }
    
    func isXcprettyAvailable() -> Bool {
        let output = main.run(bash: "which xcpretty")
        
        if output.exitcode == 0 {
            return true
        }
        
        return false
    }
}

// MARK: Xcode Workspace/Project

extension RunCommand {
    
    /**
     Create entry point for Tipsy and returns the autogenerated class path.
     */
    func createEntryPoint(workspace: String, project: String, target: String, scenarios: String) -> String? {
        print("Creating entry point")
        
        // Create temp project
        var xcodeProjectPath = Path()
        let xcodeProject: XcodeProj
        
        do {
            xcodeProjectPath = try createTempCopyOf(path: Path(project))
            xcodeProject = try XcodeProj(path: xcodeProjectPath)
        } catch {
            print("Failed to create temp project.")
            return nil
        }
        
        // Create temp workspace
        let workspacePath = Path(workspace)
        
        do {
            try createTempCopyFromWorkspaceAt(path: workspacePath,
                                              tempProjectPath: xcodeProjectPath,
                                              originalProject: project,
                                              scenarios: scenarios)
        } catch {
            print("Failed to create temp workspace.")
            return nil
        }
        
        // Create a new group under the root group.
        let autogeneratedGroup: PBXGroup
        
        do {
            let rootGroup = try xcodeProject.pbxproj.rootGroup()
            autogeneratedGroup = PBXGroup(sourceTree: .group, name: autogeneratedXcodeGroupName)
            rootGroup?.children.append(autogeneratedGroup)
            xcodeProject.pbxproj.add(object: autogeneratedGroup)
        } catch {
            print("Failed to create a new group under temp project.")
            return nil
        }
        
        // Generate file and add it to the project.
        let autogeneratedFile: PBXFileReference
        let autogeneratedFilePath: String
        
        do {
            autogeneratedFilePath = generateTestClass(scenarios: scenarios)
            autogeneratedFile = try autogeneratedGroup.addFile(at: Path(autogeneratedFilePath), sourceRoot: Path.current)
            let buildFile = PBXBuildFile(file: autogeneratedFile)
            xcodeProject.pbxproj.add(object: buildFile)
        } catch {
            print("Failed to generate entry point and add it to project.")
            return nil
        }
        
        // Get the sources build phase of the passed target and add the autogenerated file to it.
        do {
            let sourcesBuildPhase = try xcodeProject.pbxproj.targets(named: target).first?.sourcesBuildPhase()
            _ = try sourcesBuildPhase?.add(file: autogeneratedFile)
        } catch {
            print("Failed to add entry point to build phases.")
            return nil
        }
        
        // Write everything back to disk.
        do {
            try xcodeProject.write(path: xcodeProjectPath, override: true)
        } catch {
            print("Failed to save temp project to disk.")
            return nil
        }
        
        print("Created entry point at \(autogeneratedFilePath).")
        
        return autogeneratedFilePath
    }
    
    /**
     Creates a temp copy of the workspace, and modifies it to include the temp project.
     */
    func createTempCopyFromWorkspaceAt(path: Path, tempProjectPath: Path, originalProject: String, scenarios: String) throws {
        let tempXcodeWorkspacePath = try createTempCopyOf(path: path)
        let xcodeWorkspace = try XCWorkspace(path: tempXcodeWorkspacePath)
        
        try xcodeWorkspace.data.children .forEach { (dataElement) in
            switch dataElement {
            case .file(let file):
                if file.location.path.contains(originalProject) {
                    file.location = try XCWorkspaceDataElementLocationType(string: "group:\(tempProjectPath.string)")
                }
            default:
                break
            }
        }
        
        try xcodeWorkspace.write(path: tempXcodeWorkspacePath)
    }
    
    func generateTestClass(scenarios: String) -> String {
        let classDefinition = """
        //
        //  This class has been automatically generated by Tipsy.
        //  Modifications are going to be overridden with every
        //  run of Tipsy using the CLI.
        //
        //  Last generated on \(formattedDate()).
        //
        
        import Tipsy
        
        class \(entryPointClassName): TipsyTestCase {
        
            func test_startTipsyRun() {
                let scenarios = Bartender.serve(from: [
                    \(createScenarioProvidersArrayFrom(classesNames: scenarios))
                ])
        
                Tipsy.runner.add(scenarios: scenarios)
                \(replayFilePathStatement())
                \(preRunHandlerStatement())
                \(runStatementForCurrentRunMode())
        
                Tipsy.runner.wait(self)
            }
        }
        """
        
        let path = Path.current + Path("\(entryPointClassName).swift")
        
        do {
            try path.write(classDefinition)
        } catch {
            print("Failed to create \(entryPointClassName).swift")
        }
        
        return path.string
    }
    
    func createScenarioProvidersArrayFrom(classesNames: String) -> String {
        let classNamesArray = classesNames.split(separator: ",")
        let trimmedClassesNamesArray = classNamesArray.map { "\($0.trimmingCharacters(in: .whitespaces))(with: .highest)" }
        return trimmedClassesNamesArray.joined(separator: ", ")
    }
    
    func preRunHandlerStatement() -> String {
        if let preRun = preRun.value {
            return "Tipsy.runner.preRunHandler = \(preRun)"
        }
        
        return ""
    }
    
    func runStatementForCurrentRunMode() -> String {
        if comprehensive.value {
            return "Tipsy.runner.runComprehensively()"
        } else if let replayFileInputPath = replay.value {
            let escapedReplayFilePath = replayFileInputPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            
            return """
            // Replay run
                    let url = URL(string: "file://\(escapedReplayFilePath!)")!
                    let data = try! Data.init(contentsOf: url)
                    let decoder = JSONDecoder()
            
                    do {
                        let steps = try decoder.decode([Step].self, from: data)
                        Tipsy.runner.runReplayOf(steps: steps)
                    } catch {
                        fatalError("Failed to read replay file at \\(url)")
                    }
            """
        } else {
            return "Tipsy.runner.runFor(duration: \(time.value ?? 60))"
        }
    }
    
    func replayFilePathStatement() -> String {
        if let path = replayFileOutputPath.value {
            return "Tipsy.runner.replayFileOutputPath = \"\(path)\""
        }
        
        return ""
    }
}

// MARK: File Manipulation

extension RunCommand {
    
    func createTempCopyOf(path: Path) throws -> Path {
        let tempPath = tempPathFrom(path: path)
        try cleanUpTempFilesAt(path: tempPath)
        try path.copy(tempPath)
        return tempPath
    }
    
    func cleanUpTempFilesAt(path: Path) throws {
        if path.exists {
            try path.delete()
        }
    }
    
    func tempPathFrom(path: Path) -> Path {
        return Path(tempNameFrom(fileName: path.string))
    }
    
    func tempNameFrom(fileName: String) -> String {
        let nameComponents = fileName.components(separatedBy: ".")
        let tempName = "\(nameComponents[0])-temp.\(nameComponents[1])"
        
        return tempName
    }
    
    func cleanUpTempFiles(workspacePath: Path, projectPath: Path, entryPointPath: Path) {
        print("Cleaning up temp files.")
        
        do {
            try cleanUpTempFilesAt(path: workspacePath)
            try cleanUpTempFilesAt(path: projectPath)
            try cleanUpTempFilesAt(path: entryPointPath)
        } catch {
            print("Failed to clean up temp files after run.")
        }
    }
}
