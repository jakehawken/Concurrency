### CONSTANTS --------------------------------------------------
# local constants
DERIVED_DATA_PATH = "~/Library/Developer/Xcode/DerivedData/"
PROJECT_NAME = File.dirname(__FILE__).split("/").last
WORKSPACE_NAME = "Concurrency"
# file manipulation constants
FILE_CHANGED = "file modified"
NO_CHANGES = "NO_CHANGES"
FILE_SKIPPED = "file skipped"
# last line types (for handleImportsForFile function)
BOILERPLATE_LINE = "boilerplate"
IMPORT_LINE = "import"
FLAGGED_IMPORT_LINE = "flagged import"
BODY_LINE = "body line"
LINE_TO_DELETE = "marked for deletion"
###--------------------------------------------------------------


desc 'Run this to install the dependencies for this Rakefile'
task :setup do
    puts("Installing rakefile dependencies:\n")
    synxInstallSuccessful = system('gem install synx')
    xcprettyInstallSuccessful = system('gem install xcpretty')
    allSuccessful = synxInstallSuccessful and xcprettyInstallSuccessful
    if allSuccessful
        puts("\nAll rakefile dependencies installed successfully.")
    else
        outputString = "\nSome or all rakefile dependencies installed unsuccessfully:"
        if !synxInstallSuccessful
            outputString << " Synx installation failed."
        end

        if !xcprettyInstallSuccessful
            outputString << " Xcpretty installation failed."
        end

        puts(outputString)
    end
end

desc 'From a feature branch, merges back into develop and pushes'
task :mergepush do
    branchName = `git branch | grep "*"`.gsub('* ', '')
    system("git checkout develop && git pull && git merge - && git push && git branch -D #{branchName} && git push origin :#{branchName}")
end

desc 'Deletes all local branches except for master'
task :branches do
    system("git checkout master")
    branches = `git branch`.split("\n  ").select do |branch|
        !branch.include? "master"
    end

    if branches.count == 0
        puts("No feature branches to delete.")
    else
        branches.each do |branch|
            system("git branch -D #{branch}")
        end

        puts("\nResults (should only show master):")
        system("git branch")
    end
end

desc 'Deletes all local branches except for master, as well as their remotes'
task :branches_and_remotes do
    hide = `git fetch`
    hide = `git checkout master`

    localBranches = `git branch`.split("\n").map! {|x| x.gsub(' ','').gsub('*', '')}.select {|x| !x.include? "master"}

    remoteBranches = `git branch -r`.split("\n").map! {|x| x.gsub(' ','').gsub('origin/', '')}.select do |branch|
        !branch.include? "master" and !branch.include? "release"
    end

    puts("Local branches to delete: #{localBranches}")
    puts("Remote branches to delete: #{localBranches & remoteBranches}")

    if localBranches.count == 0
        puts("No branches to delete.")
    else
        localBranches.each do |branch|
            system("git branch -D #{branch}")
            if remoteBranches.include? branch
                system("git push origin :#{branch}")
            end
        end
    end

    puts("\nResults (should only show master):")
    system("git branch")
end

desc 'Imposes the virtual file structure from Xcode onto the actual file structure on disk, and sorts the files within the Xcode groups alphabetically.'
task :sort do
  system("synx #{WORKSPACE_NAME}.xcodeproj")
end

desc "From a feature branch, grabs all of the newest changes from orign/develop and merges them in, then pushes to the feature branch's remote."
task :pullrequest do
    system("git checkout develop && git pull && git checkout - && git merge develop && rake specs && git push")
end

task :constants do
    print(" PROJECT_NAME: #{PROJECT_NAME} \n WORKSPACE_NAME: #{WORKSPACE_NAME} \n DERIVED_DATA_PATH: #{DERIVED_DATA_PATH} \n")
end

task :test_config do
    puts("TestTarget: #{testTargetName}, Test Destination: #{bestTestDestination}")
end

desc 'runs all of the specs for the project. (Runs rake nof first)'
task :specs do
    puts("Preparing tests...")
    destination = bestTestDestination
    puts("Prepared. Running tests...")
    system("rake nof && rake kill && xcodebuild \
    -workspace #{WORKSPACE_NAME}.xcworkspace \
    -scheme #{WORKSPACE_NAME} \
    -sdk iphonesimulator \
    -destination #{destination} \
    -derivedDataPath #{DERIVED_DATA_PATH} \
    test | xcpretty -t & rake open")
end

desc 'runs all of the specs and then performs an analysis of the output'
task :specs_analysis do
    puts("Preparing for tests...")
    testDestination = bestTestDestination

    puts("Running tests...")
    startTime = Time.now

    specsOutput = `xcodebuild \
    -workspace #{WORKSPACE_NAME}.xcworkspace \
    -scheme #{WORKSPACE_NAME} \
    -sdk iphonesimulator \
    -destination #{testDestination} \
    test | xcpretty -s`.split("\n")

    endTime = Time.now
    totalTestTime = endTime - startTime

    performSpecsOutputAnalysis(specsOutput)
    puts("Full testing time (building + running): #{totalTestTime.round(2)} seconds.")
end

desc 'runs all code cleanup commands (nof, imports, sort)'
task :cleanup do
    system("rake sort && rake nof && rake imports")
end

desc 'remove focus from all focused tests'
task :nof do
    testFiles = Dir.glob("#{testTargetName}/**/*.swift")
    puts("All the spec files: #{testFiles}")
    testFiles.each do |file|
        newRows = []
        File.open(file, 'r').each do |line|
            newRows << line.gsub('fit(', 'it(').gsub('fdescribe(', 'describe(').gsub('fcontext(', 'context(')
        end
        contentOfArray = newRows.join
        File.open(file, 'w').write contentOfArray
    end
    print("All tests, describes, and contexts have been unfocused.\n")
end

desc 'remove bypass from all bypassed tests'
task :nox do
    testFiles = Dir.glob("#{testTargetName}/**/*Tests.swift")
    testFiles.each do |file|
        newRows = []
        File.open(file, 'r').each do |line|
            newRows << line.gsub('xit(', 'it(').gsub('xdescribe(', 'describe(').gsub('xcontext(', 'context(')
        end
        contentOfArray = newRows.join
        File.open(file, 'w').write contentOfArray
    end
    print("All tests, describes, and contexts have been un-bypassed.\n")
end

desc 'Updates the cocoapods'
task :pod do
    system("rake kill && pod repo update && pod update && rake open")
end

desc "Checks the cocapod to make sure it's a valid cocoapod"
task :lint do
  system("pod lib lint #{WORKSPACE_NAME}.podspec --allow-warnings")
end

desc 'Attempts to publish the current version to cocoapods.'
task :publish do
  system("pod trunk push #{WORKSPACE_NAME}.podspec --allow-warnings")
end

desc 'kills xcode and simulator processes'
task :kill do
    system('[$(ps -A | grep /Applications/Xcode.app/Contents/MacOS/Xcode | grep ??) == ""] || killall "Xcode"')
end

desc 'opens the project'
task :open do
    system("open #{WORKSPACE_NAME}.xcworkspace")
end

# HELPERS -----------------------------------------------------------------------------------------------------------------------------

def testTargetName
    return "#{WORKSPACE_NAME}Tests"
end

def bestTestDestination
    allDestinations = `xcodebuild \ -workspace #{WORKSPACE_NAME}.xcworkspace -scheme #{WORKSPACE_NAME} -sdk iphonesimulator -showdestinations`
    allDestinations = allDestinations.split("Ineligible destinations").first.chomp.split("\n").select { |e| e.include? "{ platform:" }
    last = allDestinations.last.chomp.split('{ ').last.gsub(' }', '')
    relevantPairs = last.split(', ').select { |e| e.include? 'platform:' or e.include? 'name:' or e.include? 'OS:' }
    return "'#{relevantPairs.join(',').gsub(':','=')}'"
end

def deleteLocalAndRemote(branchName)
    if !branchName.include? "develop"
        system("git branch -D #{branch} && git push origin :#{branch}")
    elsif
        puts("Nope! Not gonna let you do that, buddy.")
    end
end

def performSpecsOutputAnalysis(specsOutput)
    # FORMATTING THE INPUT DATA -------------------------------------------------------------
    truncatedOutput = []
    hasFoundTestStart = false
    specsOutput.each do |line|
        if hasFoundTestStart  # Only include console spew from after the tests began.
            truncatedOutput << line.chomp
        elsif line.include? "Test Suite" and line.include? "started"
            hasFoundTestStart = true
        end
    end
    specsOutput = truncatedOutput

    totalTestsCount = specsOutput.select { |line| line.include? " seconds)" }.count
    totalTestsDuration = 0.0

    fileArrays = Hash.new
    currentFileLines = []
    currentFileDuration = 0.0

    # Breaking the testing output into files and getting the total duration (per file) of the tests
    specsOutput.each_with_index do |line, index|
        if !line.include? " seconds)" || index + 1 == specsOutput.count
            if currentFileLines.count > 0
                fileHeader = currentFileLines.first + " (Total file duration: #{currentFileDuration.round(3)})"
                currentFileLines[0] = fileHeader

                # Sorting tests within a file by length.
                sortedTests = currentFileLines[1,currentFileLines.count].sort { |x,y|
                    xSortable = x.split(" seconds)").first.split(" (").last.to_f
                    ySortable = y.split(" seconds)").first.split(" (").last.to_f
                    ySortable <=> xSortable
                }
                sortedTests.insert(0, fileHeader)

                fileArrays[fileHeader] = sortedTests
                currentFileLines = []
                currentFileDuration = 0.0
            end
        elsif line.include? " seconds)"
            currentTestDuration = line.split(" seconds)").first.split("(").last.to_f
            totalTestsDuration += currentTestDuration
            currentFileDuration += currentTestDuration
        end
        currentFileLines << line
    end
    totalTestsDuration = totalTestsDuration.round(3)

    # Sorting files by testing duration
    sortedKeys = fileArrays.keys.sort { |x,y|
        xSortable = x.split(" (Total file duration: ").last.split(")").first.to_f
        ySortable = y.split(" (Total file duration: ").last.split(")").first.to_f
        ySortable <=> xSortable
    }
    specsOutput = sortedKeys.map { |key|
        fileArrays[key]
    }.flatten

    # ANALYSIS ------------------------------------------------------------------------------
    puts("Analyzing test output")

    minimumThreshold = 0.01
    maxDisparity = 0.0
    finalTestCountAboveThreshold = 0.0
    finalDurationOfTestsAboveThreshold = 0.0
    finalThreshold = 0.0
    finalPercentageOfTotalTestCount = 0.0
    finalPercentageOfTotalTestDuration = 0.0
    relevantLines = []

    while minimumThreshold < 0.5
        print(".")
        lines = []
        testCountAboveThreshold = 0
        durationOfTestsAboveThreshold = 0.0

        specsOutput.each do |line|
            if line.include? " seconds)"
                lengthOfTest = line.split(" seconds)").first.split("(").last.to_f
                if lengthOfTest > minimumThreshold
                    testCountAboveThreshold += 1
                    durationOfTestsAboveThreshold += lengthOfTest
                    lines << line
                end
            else
                lines << line
            end
        end

        durationOfTestsAboveThreshold = durationOfTestsAboveThreshold.round(3)
        asPercentageOfTotalTestCount = ((testCountAboveThreshold.to_f/totalTestsCount.to_f)*100).round(3)
        asPercentageOfTotalTestDuration = ((durationOfTestsAboveThreshold/totalTestsDuration)*100).round(3)

        disparity = asPercentageOfTotalTestDuration-asPercentageOfTotalTestCount
        if disparity > maxDisparity
            maxDisparity = disparity
            finalTestCountAboveThreshold = testCountAboveThreshold
            finalThreshold = minimumThreshold
            finalPercentageOfTotalTestCount = asPercentageOfTotalTestCount
            finalPercentageOfTotalTestDuration = asPercentageOfTotalTestDuration
            finalDurationOfTestsAboveThreshold = durationOfTestsAboveThreshold

            relevantLines = []
            lines.each do |line|
                if !line.include? " seconds)"
                    if relevantLines.count > 0 and !relevantLines.last.include? " seconds)"
                        relevantLines.pop
                    end
                    relevantLines << line
                else
                    relevantLines << line
                end
            end
            if !relevantLines.last.include? " seconds)"
                relevantLines.pop
            end
        end
        minimumThreshold += 0.01
    end

    print("DONE.\n")
    relevantLines.each { |line| puts(line) }
    if finalTestCountAboveThreshold > 0
        puts("\nOut of #{totalTestsCount} tests, there were #{finalTestCountAboveThreshold} tests that each took more than #{finalThreshold.round(2)} seconds.")
        puts("These tests make up #{finalPercentageOfTotalTestCount.round(2)}% of the total number of tests, but account for #{finalPercentageOfTotalTestDuration.round(3)}% of the duration of testing.")
        puts("(#{finalDurationOfTestsAboveThreshold} out of #{totalTestsDuration} total seconds.)")
    else
        puts("Tests running at a consistent speed.")
    end
end
