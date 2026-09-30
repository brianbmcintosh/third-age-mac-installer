import Foundation

func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw InstallerError("TEST FAILED: "+message) }
}
func expectFailure(_ label: String, _ block: () throws -> Void) throws {
    do { try block() } catch { print("PASS: \(label)");return }
    throw InstallerError("TEST FAILED: expected rejection for "+label)
}
@main struct CoreTests {
    static func main() {
        do {
            let args = CommandLine.arguments
            guard args.count >= 3 else { throw InstallerError("Usage: CoreTests selftest FIXTURES | install GAME PART1 PART2 | cancel GAME PART1 PART2") }
            if args[1] == "selftest" { try selftest(URL(fileURLWithPath:args[2])) }
            else {
                guard args.count == 5 else { throw InstallerError("Two archive paths required") }
                let game = try GameLocation(URL(fileURLWithPath:args[2]),fixture:true)
                let files = [URL(fileURLWithPath:args[3]),URL(fileURLWithPath:args[4])]
                ta_set_cancelled(0)
                var last = -1
                var cancelTriggered = false
                let task = {
                    let report = try Installer().install(game:game,downloads:files) { fraction,message in
                        let pct = Int(fraction*100)
                        if pct >= last+5 { print("\(pct)% \(message)");fflush(stdout);last = pct }
                        if args[1] == "cancel" && fraction > 0.26 { cancelTriggered = true;ta_set_cancelled(1) }
                    }
                    print("PASS: installed \(report.fileCount) files; verified \(report.publisherFilesVerified) publisher checksums")
                }
                if args[1] == "cancel" {
                    try expectFailure("cancel partial extraction",task)
                    try require(cancelTriggered,"cancellation test failed before reaching extraction")
                    try require(!FileManager.default.fileExists(atPath:game.target.path),"cancelled installation was published")
                    try require(try FileManager.default.contentsOfDirectory(atPath:game.mods.path).allSatisfy { !$0.hasPrefix(".third-age-install-") },"temporary files remained after cancellation")
                } else { try task() }
            }
        } catch { fputs(error.localizedDescription+"\n",stderr);exit(1) }
    }
    static func selftest(_ fixtures: URL) throws {
        let fm = FileManager.default
        let output = fixtures.appendingPathComponent("output")
        try fm.createDirectory(at:output,withIntermediateDirectories:true)
        for method in ["stored","zlib","bz2"] {
            let input = fixtures.appendingPathComponent(method+".bin")
            let data = try Data(contentsOf:fixtures.appendingPathComponent("expected.bin"))
            let file = try FileHandle(forReadingFrom:input)
            defer { try? file.close() }
            let length = try file.seekToEnd()
            let target = output.appendingPathComponent(method)
            try extractStream(file,offset:0,packed:length,size:UInt64(data.count),to:target)
            try require(try Data(contentsOf:target) == data,"\(method) output mismatch")
            try expectFailure("\(method) existing output preserved") {
                try extractStream(file,offset:0,packed:length,size:UInt64(data.count),to:target)
            }
            try require(try Data(contentsOf:target) == data,"existing file altered")
            try expectFailure("\(method) truncated input") {
                try extractStream(file,offset:0,packed:length-3,size:UInt64(data.count),to:output.appendingPathComponent(method+"-truncated"))
            }
            try require(!fm.fileExists(atPath:output.appendingPathComponent(method+"-truncated").path),"failed output remained")
            if method != "stored" {
                try expectFailure("\(method) declared-size overflow") {
                    try extractStream(file,offset:0,packed:length,size:UInt64(data.count-7),to:output.appendingPathComponent(method+"-overflow"))
                }
            }
        }
        let link = output.appendingPathComponent("symlink")
        let existing = output.appendingPathComponent("zlib")
        try fm.createSymbolicLink(at:link,withDestinationURL:existing)
        let file = try FileHandle(forReadingFrom:fixtures.appendingPathComponent("zlib.bin"))
        defer { try? file.close() }
        let size = try file.seekToEnd()
        try expectFailure("output symlink is refused") { try extractStream(file,offset:0,packed:size,size:1,to:link) }
        for path in ["../escape","mods/third_age_3/../escape","mods/third_age_3//bad","mods/third_age_3/./bad","/mods/third_age_3/bad","mods/other/data","mods/third_age_3/C:bad"] {
            try expectFailure("unsafe path \(path)") { _ = try relativePath(path) }
        }
        try require(try relativePath("mods\\third_age_3\\Data\\Valid.txt") == "data/valid.txt","Windows path normalization")
        try expectFailure("truncated file list") { _ = try parseEntries(Data([1,0,0,0]),dataSize:100) }
        try expectFailure("invalid file count") { _ = try parseEntries(Data([255,255,255,255]),dataSize:100) }
        ta_set_cancelled(1)
        try expectFailure("cancellation token") { try checkCancelled() }
        ta_set_cancelled(0)
        print("PASS: parser and decompression safeguards")
    }
}
