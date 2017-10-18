### CONSTANTS --------------------------------------------------
# local constants
DERIVED_DATA_PATH = "~/Library/Developer/Xcode/DerivedData/"
DESTINATION = "'platform=iOS Simulator,name=iPhone 7,OS=10.2'"
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

def deleteLocalAndRemote(branchName)
    if !branchName.include? "develop"
        system("git branch -D #{branch} && git push origin :#{branch}")
    elsif
        puts("Nope! Not gonna let you do that, buddy.")
    end
end

desc "From a feature branch, grabs all of the newest changes from orign/develop and merges them in, then pushes to the feature branch's remote."
task :pullrequest do
    system("git checkout develop && git pull && git checkout - && git merge develop && rake specs && git push")
end

task :constants do
    print(" PROJECT_NAME: #{PROJECT_NAME} \n WORKSPACE_NAME: #{WORKSPACE_NAME} \n DESTINATION: #{DESTINATION} \n DERIVED_DATA_PATH: #{DERIVED_DATA_PATH} \n")
end

desc 'runs all of the specs for the project. (Runs rake nof first)'
task :specs do
    system("rake nof && rake kill && xcodebuild \
    -workspace #{WORKSPACE_NAME}.xcworkspace \
    -scheme #{WORKSPACE_NAME}Tests \
    -sdk iphonesimulator \
    -destination #{DESTINATION} \
    -derivedDataPath #{DERIVED_DATA_PATH} \
    test | xcpretty -t & rake open")
end

desc 'runs all code cleanup commands (nof, imports, sort)'
task :cleanup do
    system("rake sort && rake nof && rake imports")
end

desc 'remove focus from all focused tests'
task :nof do
    testFiles = Dir.glob("#{WORKSPACE_NAME}Tests/**/*.swift")
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
    testFiles = Dir.glob("#{WORKSPACE_NAME}Tests/**/*Tests.swift")
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

desc 'sorts all imports & removes duplicates, and standardizes tops of all .swift files'
task :imports do

    swiftFiles = Dir.glob("Source/*.swift") + Dir.glob("ConcurrencyTests/*.swift")

    # # Debug - This is for debugging on a single file.
    # # To use, comment out the .each loop above and uncomment the following,
    # # then replace the file name on the `filename.include?` line as you see fit:
    # swiftFiles = swiftFiles.select{ |filename|
    #     filename.include? "ValidateNotificationButton"
    # }

    sortImportsAndPrintResultsForFiles swiftFiles
end

desc 'runs the imports command on all files modified on the current git branch'
task :imports_branch do
    branchName = `git branch | grep "*"`.gsub('* ', '').split("\n").first

    if branchName == "develop"
        puts("On develop. No diff to consider.")
        return
    end

    diffSwiffFiles = `git diff --name-status develop | grep swift`.split("\n")

    modifiedSwiftFiles = []

    diffSwiffFiles.each do |line|
        if line.start_with?("M\t") or line.start_with?("A\t")
            modifiedSwiftFiles << line.split("\t").last
        end
    end
    puts("Checking all Swift files modified on branch: #{branchName}.")
    sortImportsAndPrintResultsForFiles modifiedSwiftFiles
end

desc 'calls "handleImportsForFile" on an array of swift files and prints the results of all calls'
def sortImportsAndPrintResultsForFiles(filesToModify)
    # # Debug
    # puts("Swift file(s) to scan:\n")
    # if filesToModify.count == 0
    #     puts ("NONE.")
    #     return
    # else
    #     filesToModify.each do |fileName|
    #         puts(fileName)
    #     end
    # end

    filesChanged = 0
    filesNotChanged = 0
    filesSkipped = 0

    filesToModify.each do |filename|
        returnValue = handleImportsForFile filename
        if returnValue == FILE_CHANGED
            print(".")
            filesChanged = filesChanged + 1
        elsif returnValue == NO_CHANGES
            print("-")
            filesNotChanged = filesNotChanged + 1
        elsif returnValue == FILE_SKIPPED
            print(">")
            filesSkipped = filesSkipped + 1
        end
    end

    totalCount = filesToModify.count
    puts("\nFinished scanning import lines in #{totalCount} swift files.")
    puts("#{filesChanged} files modified (.), #{filesNotChanged} files unchanged (-), and #{filesSkipped} files had no imports to sort (>).")
end

def handleImportsForFile(filename)
    className = filename.split("/").last.split(".").first

    # # Debug
    # puts("======>NEW FILE: #{filename.split("/").last} <=======================")
    # puts("STRIPPED FILENAME == #{className}")

    firstRead           = []
    firstReadConsolidated = ""
    boilerplateLines    = []
    importLines         = []
    flaggedImportLines  = []
    bodyLines           = []

    hasFoundImportBeginning = false
    hasFoundBodyBeginning = false

    lastLineType = BOILERPLATE_LINE
    lastLine = ""

    originalLines = File.open(filename, 'r')

    originalLines.each_with_index do |line, index|
        firstRead << line #writes every single line to the 'firstRead' array for final comparison at end
        currentLineType = BOILERPLATE_LINE

        # determining curent line type
        if hasFoundBodyBeginning
            currentLineType = BODY_LINE
        elsif line == "\n" or line == "//\n" or line == " \n"
            currentLineType = LINE_TO_DELETE
            # # Debug
            # puts("LINE MARKED FOR DELETION: #{[line]}")
        elsif hasFoundImportBeginning
            if line.start_with?("import ") or line.start_with?("@testable import ")
                if lastLineType == FLAGGED_IMPORT_LINE and !lastLine.start_with?("#endif")
                    currentLineType = FLAGGED_IMPORT_LINE
                else
                    currentLineType = IMPORT_LINE
                end
            elsif line.start_with?("#if") or line.start_with?("#else") or line.start_with?("#endif")
                currentLineType = FLAGGED_IMPORT_LINE
            else
                currentLineType = BODY_LINE
                hasFoundBodyBeginning = true
            end
        elsif line.start_with?("//")
            currentLineType = BOILERPLATE_LINE
        elsif line.start_with?("@testable import ") or line.start_with?("import ") or line.start_with?("#if")
            hasFoundImportBeginning = true

            if line.start_with?("#if")
                currentLineType = FLAGGED_IMPORT_LINE
            else
                currentLineType = IMPORT_LINE
            end
        else
            currentLineType = BODY_LINE
            hasFoundBodyBeginning = true
        end

        #switching on current line type
        if currentLineType == BOILERPLATE_LINE
            boilerplateLines << line.gsub("#{WORKSPACE_NAME}_Example", "#{WORKSPACE_NAME}")
        elsif currentLineType == IMPORT_LINE
            importLines << line
        elsif currentLineType == FLAGGED_IMPORT_LINE
            flaggedImportLines << line
        elsif currentLineType == BODY_LINE
            # # Debug
            # if lastLineType != BODY_LINE
            #     puts("FIRST BODY LINE AT INDEX #{index}: #{[line]}")
            #     puts("REASON:\n found body beginning: #{hasFoundBodyBeginning}\n found import beginning: #{hasFoundImportBeginning}\n last line was flagged import: #{line == FLAGGED_IMPORT_LINE}\n line is empty comment: #{line == "//\n"}\n line is empty line: #{line == "\n"}\n line is import: #{line.start_with?("@testable import ") or line.start_with?("import ") or line.start_with?("#if")}")
            # end
            bodyLines << line
        else
            # Since no work happens in this else case,
            # lines that end up here will be deleted.
            # # Debug
            # puts("DELETING: #{[line]}")
        end

        lastLine = line
        if currentLineType != LINE_TO_DELETE
            lastLineType = currentLineType
        end
    end

    firstReadConsolidated = firstRead.join

    if importLines.count + flaggedImportLines.count == 0
        # # Debug
        # puts("Less than 2 imports in file: #{filename.split("/").last}")
        # puts("Boilerplate: #{boilerplateLines}")
        # puts("Vanilla Imports: #{importLines}")
        # puts("Flagged Imports: #{flaggedImportLines}")
        return FILE_SKIPPED
    end

    #this sorts the import lines normally except that it puts the <> imports at the top.
    importLines.sort! { |a,b|
        if a.include? "<" and !b.include? "<"
            -1
        elsif !a.include? "<" and b.include? "<"
            +1
        elsif !a.start_with?("@") and b.start_with?("@")
            -1
        elsif a.start_with?("@") and !b.start_with?("@")
            +1
        else
            a <=> b
        end
    }

    importLines.uniq!

    # # Debug
    # puts("Boilerplate Lines: \n#{boilerplateLines}\n")
    # puts("\nImport Lines: \n")
    # importLines.each do |line|
    #     puts(line)
    # end
    # puts("\nBody Lines:\n")
    # bodyLines.each do |line|
    #     puts(line)
    # end

    #append flagged imports to imports
    if flaggedImportLines.count > 0
        if importLines.count > 0
            importLines << "\n"
        end
        importLines = importLines + flaggedImportLines
    end

    newRows = []

    if boilerplateLines.count > 0
        newRows << boilerplateLines
    end

    if importLines.count > 0
        if newRows.count > 0
            newRows << "\n"
        end
        newRows << importLines
    end

    if bodyLines.count > 0
        if newRows.count > 0
            newRows << "\n\n"
        end
        newRows << bodyLines
    end

    newRowsConsolidated = newRows.join

    # # Debug
    # puts("FILE WAS CHANGED: #{firstReadConsolidated == newRowsConsolidated}")

    #DETERMINING IF CHANGES WERE MADE
    if firstReadConsolidated == newRowsConsolidated
        return NO_CHANGES
    else
        #ACTUALLY WRITING BACK TO THE FILE
        File.open(filename, 'w').write newRows.join
        originalLines.close
        return FILE_CHANGED
    end
end
