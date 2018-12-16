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
