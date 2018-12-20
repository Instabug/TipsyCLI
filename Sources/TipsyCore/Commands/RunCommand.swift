/*
 tipsy run runmode options
 runmode:
 1. time
  Options
      Time in minutes
      Example: tipsy run time 10
 2. comprehensive

 Specifying names of scenario classes to run:
 * By default, all classes with the "Scenarios.swift" prefix should be included.
 * Add the option of specifying class names. (keyed options)
 
 tipsy run comprehensive --class APIScenarios.swift
 tipsy run time 15 --class APIScenarios.swift
--
 Todo:
 1. Work on the command that runs all for time
    a. Explore if a Tipsyfile is needed to specify things like the target to test
    b. Start by running the Xcode command to run tests for Test.swift
        xcodebuild -workspace Tipsy.xcworkspace -scheme Tipsy-Example -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=12.1,name=iPhone 8' -only-testing:Tipsy_Tests/Test test
        Note: after the file is generated, it also needs to be added to the test target that has the Scenarios
        See:
            https://github.com/tuist/xcodeproj
            https://github.com/tuist/xcodeproj/issues/341
            Add a new group to add the file to:
            https://github.com/tuist/xcodeproj/issues/43
            Add file to group:
            https://github.com/tuist/xcodeproj/issues/57
 
            https://github.com/CocoaPods/Xcodeproj
 
    c. Work on generating a temp test.swift file
    d. Figure out how to reset the simulator before starting the run
 
--
 How Tipsy should be used:
 
 App
    - Adds Tipsy via CocoaPods
    - Adds a test target that contains all scanarios
    - Uses CLI to run that target, so scheme and workspace need to be specified.
 
*/
import SwiftCLI
import xcodeproj
import PathKit
import SwiftShell
import Foundation

class RunCommand: Command {
    let name = "run"
    let shortDescription = "🏃🏻‍♀️"
    
    let xcodeWorkspaceName = Parameter()
    let xcodeProjectName = Parameter()
    let xcodeTargetName = Parameter()
    let scenarioProviders = Parameter()
    let runType = OptionalParameter()
    
    let time = Key<Int>("-t", "--time", description: "Time to keep running Tipsy for.")
    let comprehensive = Flag("-c", "--comprehensive", description: "Do a comprehensive run.")
    
    var optionGroups: [OptionGroup] {
        let runMode: OptionGroup = .atMostOne(time, comprehensive)
        return [runMode]
    }
    
    let autogeneratedXcodeGroupName = "Tipsy Autogenerated"
    let entryPointClassName = "Tipsy_EntryPoint"
    
    /* Things command needs to run:
     * 1. workspace name
     * 2. Names of ScenarioProviders to run
     * 3. Name of test target that contains the scenarios
     * 4. Name of scheme to run
     *
     * Things command should do:
     * 1. Create test class
     * 2. Clean up simulator (add --no-reset option)
     * 3. Run xcodebuild command
     * 4. Clean up all temp files after run
     */
    
    func execute() throws {
        do {
            let entryPointPath = try createEntryPoint()
            print(entryPointPath)
            
            let tempWorkspaceName = tempNameFrom(fileName: xcodeWorkspaceName.value)
            
            startTipsyRun(workspaceName: tempWorkspaceName,
                          targetName: xcodeTargetName.value,
                          entryPointName: entryPointClassName)
        } catch {
            print("Failed to generate entry point.")
        }
    }
    
    func formattedDate() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy hh:mm a"
        return formatter.string(from: date)
    }
}

// MARK: Xcode build

extension RunCommand {
    
    func startTipsyRun(workspaceName: String, targetName: String, entryPointName: String) {
        let testCommand = "xcodebuild -workspace \(workspaceName) -scheme \(targetName) -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=12.1,name=iPhone XS' -only-testing:\(targetName)/\(entryPointName) test"
        
        do {
            try main.runAndPrint(bash: testCommand)
        } catch {
            print("Something went wrong while trying to run test command.")
        }
    }
}

// MARK: Xcode Workspace/Project

extension RunCommand {
    
    /**
     Create entry point for Tipsy and returns the autogenerated class path.
     */
    func createEntryPoint() throws -> String {
        // Create temp project
        var xcodeProjectPath = Path()
        
        do {
            xcodeProjectPath = try createTempCopyOf(path: Path(xcodeProjectName.value))
        } catch {
            print("Failed to create temp project.")
        }
        
        let xcodeProject = try XcodeProj(path: xcodeProjectPath)

        
        // Create temp workspace
        let workspacePath = Path(xcodeWorkspaceName.value)
        do {
            try createTempCopyFromWorkspaceAt(path: workspacePath, tempProjectPath: xcodeProjectPath)
        } catch {
            print("Failed to create temp workspace.")
        }
        
        // Create a new group under the root group.
        let rootGroup = try xcodeProject.pbxproj.rootGroup()
        let autogeneratedGroup = PBXGroup(sourceTree: .group, name: autogeneratedXcodeGroupName)
        rootGroup?.children.append(autogeneratedGroup)
        xcodeProject.pbxproj.add(object: autogeneratedGroup)
        
        // Generate file and add it to the project.
        let autogeneratedFilePath = generateTestClass()
        let autogeneratedFile = try autogeneratedGroup.addFile(at: Path(autogeneratedFilePath), sourceRoot: Path.current)
        let buildFile = PBXBuildFile(file: autogeneratedFile)
        xcodeProject.pbxproj.add(object: buildFile)
        
        // Get the sources build phase of the passed target and add the autogenerated file to it.
        let sourcesBuildPhase = try xcodeProject.pbxproj.targets(named: xcodeTargetName.value).first?.sourcesBuildPhase()
        _ = try sourcesBuildPhase?.add(file: autogeneratedFile)
        
        // Write everything back to disk.
        try xcodeProject.write(path: xcodeProjectPath, override: true)
        
        return autogeneratedFilePath
    }
    
    /**
     Creates a temp copy of the workspace, and modifies it to include the temp project.
     */
    func createTempCopyFromWorkspaceAt(path: Path, tempProjectPath: Path) throws {
        let tempXcodeWorkspacePath = try createTempCopyOf(path: path)
        let xcodeWorkspace = try XCWorkspace(path: tempXcodeWorkspacePath)
        
        try xcodeWorkspace.data.children .forEach { (dataElement) in
            switch dataElement {
            case .file(let file):
                if file.location.path.contains(xcodeProjectName.value) {
                    file.location = try XCWorkspaceDataElementLocationType(string: "group:\(tempProjectPath.string)")
                }
            default:
                break
            }
        }
        
        try xcodeWorkspace.write(path: tempXcodeWorkspacePath)
    }
    
    func generateTestClass() -> String {
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
                let scenarios = Bartender.serve(fromProviders: [
                    \(createScenarioProvidersArrayFrom(classesNames: scenarioProviders.value))
                ])
        
                Tipsy.runner.add(scenarios: scenarios)
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
        let trimmedClassesNamesArray = classNamesArray.map { "\($0.trimmingCharacters(in: .whitespaces)).self" }
        return trimmedClassesNamesArray.joined(separator: ", ")
    }
    
    func runStatementForCurrentRunMode() -> String {
        if comprehensive.value {
            return "Tipsy.runner.runComprehensively()"
        } else {
            return "Tipsy.runner.runFor(duration: \(time.value ?? 60))"
        }
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
}
