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

class RunCommand: Command {
    let name = "run"
    let shortDescription = "🏃🏻‍♀️"
    
//    let gitHubOrganization = Parameter()
//    let gitHubUsername = Parameter()
    
    func execute() throws {
        let path = Path("/Users/Hesham/Documents/Work/iOS/Tipsy/Example/Tipsy.xcodeproj")
        let project = try! XcodeProj(path: path)
        
//        for group in project.pbxproj.groups {
//            print(group.name)
//        }
        
//        let existingGroup = project.pbxproj.groups.first { $0.name == "Example for Tipsy" }!
        let existingGroup = try project.pbxproj.rootGroup() // { $0.name == "Example for Tipsy" }!

        
        let newGroup = PBXGroup(sourceTree: .group,
                                name: "CustomPBXGroup")
        
        existingGroup?.children.append(newGroup)
        
//        project.pbxproj.nativeTargets.forEach { (target) in
//            print(target.name)
//        }
        
        ///
        
//        let project = try! XcodeProj(path: "testing.xcodeproj")
//        let newGroup = PBXGroup(children: [],
//                             sourceTree: project.pbxproj.groups[0].sourceTree, name: "TipsysAutoGen")
//        group.name = "CustomPBXGroup"
//        project.pbxproj.objects.append(.pbxGroup(group))
//        try! project.write(path: "testing.xcodeproj", override: true)
        
        ///
        
//        let newGroup = PBXGroup(children: <#T##[PBXFileElement]#>, sourceTree: <#T##PBXSourceTree?#>, name: <#T##String?#>, path: <#T##String?#>, includeInIndex: <#T##Bool?#>, wrapsLines: <#T##Bool?#>, usesTabs: <#T##Bool?#>, indentWidth: <#T##UInt?#>, tabWidth: <#T##UInt?#>)
        
//            let fi
        
        // find your existing group
//        let existingGroup = project.pbxproj.groups.first { $0.name == "ExistingGroup" }!
        
        // append the new group to the existing groups children
//        existingGroup.children.append(newGroup.reference)
        
        //add the new group to the the list of groups
        project.pbxproj.add(object: newGroup) //groups.append(newGroup)
//        project.pbxproj.groups
//        project.pbxproj.targets(named: "Tipsy_Tests").first?.sourceFiles().a
    
        let file = try newGroup.addFile(at: Path("/Users/Hesham/Documents/Work/iOS/Tipsy/Example/AutogenTest.swift"), sourceRoot: Path("/Users/Hesham/Documents/Work/iOS/Tipsy/Example/"))
        let buildFile = PBXBuildFile(file: file)
        
        project.pbxproj.add(object: buildFile)
        
//        project.pbxproj.targets(named: "Tipsy_Tests").first?

        
//        let phases = project.pbxproj.sourcesBuildPhases
        
        let phase = try project.pbxproj.targets(named: "Tipsy_Tests").first?.sourcesBuildPhase()
        
        try phase?.add(file: file)
        
//        if let phase = phase {
//
//        }
        
        try! project.write(path: path, override: true)
    }
}
