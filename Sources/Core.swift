import Foundation
import CryptoKit

struct InstallerError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

enum Constants {
    static let version = "0.1.0-beta.1"
    static let downloadPage = "https://steamcommunity.com/sharedfiles/filedetails/?id=863223393"
    static let modName = "third_age_3"
    static let prefix = "mods/third_age_3/"
    // Exact Gigantus two-part 3.2 compilation tested during development.
    static let archives: [String: (Int, UInt64)] = [
        "3a827ff091541d9325f4852c1c63966e1bf1be6f7459d2b088a9c98e32a9fc0e": (1, 1_835_183_234),
        "2970d57990632eaf2c7fb348bd32e730424314fb44de7ecad4b78765d859c168": (2, 2_059_165_989)
    ]
}

func checkCancelled() throws {
    if ta_is_cancelled() != 0 { throw InstallerError("Installation cancelled. Your existing game and mods were left in place.") }
}

extension Data {
    func uint16(_ at: Int) throws -> UInt16 {
        guard at >= 0, at <= count-2 else { throw InstallerError("Truncated archive header.") }
        return UInt16(self[at]) | UInt16(self[at+1]) << 8
    }
    func uint32(_ at: Int) throws -> UInt32 {
        guard at >= 0, at <= count-4 else { throw InstallerError("Truncated archive header.") }
        return UInt32(self[at]) | UInt32(self[at+1]) << 8 | UInt32(self[at+2]) << 16 | UInt32(self[at+3]) << 24
    }
}

func read(_ handle: FileHandle, at offset: UInt64, count: Int) throws -> Data {
    try handle.seek(toOffset: offset)
    let data = try handle.read(upToCount: count) ?? Data()
    guard data.count == count else { throw InstallerError("The selected installer is incomplete. Download it again.") }
    return data
}

func relativePath(_ name: String) throws -> String {
    let normalized = name.replacingOccurrences(of: "\\", with: "/")
    guard normalized.hasPrefix(Constants.prefix), !normalized.contains(":"),
          !normalized.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else {
        throw InstallerError("The archive contains an unexpected file path.")
    }
    let result = String(normalized.dropFirst(Constants.prefix.count))
    let parts = result.split(separator: "/", omittingEmptySubsequences: false)
    guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
        throw InstallerError("The archive contains an unsafe file path.")
    }
    return result.lowercased()
}

struct Entry {
    let path: String
    let size: UInt64
    let offset: UInt64
    let packed: UInt64
}

func parseEntries(_ list: Data, dataSize: UInt64) throws -> [Entry] {
    let count = Int(try list.uint32(0))
    guard count > 0, count <= 25_000 else { throw InstallerError("Unexpected archive file count.") }
    var position = 4, result: [Entry] = [], seen = Set<String>()
    for _ in 0..<count {
        let length = Int(try list.uint32(position)), kind = try list.uint16(position+4)
        guard length >= 40, position <= list.count-length else { throw InstallerError("Invalid archive file record.") }
        guard kind == 0 else { throw InstallerError("This archive uses an unsupported file-record type.") }
        let empty = list[position+9] == 0xe2
        let nameStart = position+(empty ? 40 : 64)
        guard nameStart < position+length else { throw InstallerError("Missing archive filename.") }
        let bytes = list[nameStart..<position+length].prefix(while: { $0 != 0 })
        guard let name = String(data: bytes, encoding: .windowsCP1252) else { throw InstallerError("Invalid archive filename.") }
        let path = try relativePath(name)
        guard seen.insert(path).inserted else { throw InstallerError("Duplicate archive filename: \(path)") }
        let size = empty ? 0 : UInt64(try list.uint32(position+24))
        let offset = empty ? 0 : UInt64(try list.uint32(position+28))
        let packed = empty ? 0 : UInt64(try list.uint32(position+32))
        guard size <= 512_000_000, offset <= dataSize, packed <= dataSize-offset,
              size == 0 || packed > 0 else { throw InstallerError("Archive file size or offset is invalid.") }
        result.append(Entry(path: path, size: size, offset: offset, packed: packed))
        position += length
    }
    guard position == list.count else { throw InstallerError("Unexpected data after the archive file list.") }
    return result
}

func extractStream(_ source: FileHandle, offset: UInt64, packed: UInt64, size: UInt64, to output: URL) throws {
    var message = [CChar](repeating: 0, count: 512)
    let status = output.path.withCString {
        ta_extract(source.fileDescriptor, offset, packed, size, $0, &message, message.count)
    }
    if status != 0 { try checkCancelled(); throw InstallerError(String(cString: message)) }
}

final class Archive {
    let file: FileHandle
    let size: UInt64
    let number: Int
    let entries: [Entry]
    let dataStart: UInt64
    init(url: URL, scratch: URL, progress: (Double, String) -> Void) throws {
        file = try FileHandle(forReadingFrom: url)
        size = try file.seekToEnd()
        guard Constants.archives.values.map(\.1).contains(size) else {
            throw InstallerError("Choose the two Gigantus ‘TATW 3.2 part 1 of 2.exe’ and ‘part 2 of 2.exe’ downloads. This file has a different size. Original 3.0/patch installers and other editions are not supported.")
        }
        try file.seek(toOffset: 0)
        var hash = SHA256(), processed: UInt64 = 0
        while let block = try file.read(upToCount: 1_048_576), !block.isEmpty {
            try checkCancelled(); hash.update(data: block); processed += UInt64(block.count)
            progress(Double(processed)/Double(size), "Checking \(url.lastPathComponent)…")
        }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard let identity = Constants.archives[digest], identity.1 == size else {
            throw InstallerError("This download does not match the tested Third Age 3.2 package. It may be incomplete or a different release. Please use the downloads linked from the helper.")
        }
        number = identity.0
        let header = try read(file, at: 0, count: min(Int(size), 1_048_576))
        guard let signature = header.range(of: Data([0x77,0x77,0x67,0x54,0x29,0x48])) else {
            throw InstallerError("The Clickteam archive header was not found.")
        }
        var offset = UInt64(signature.upperBound), list: Data?, dataOffset: UInt64?, dataLength: UInt64?
        for _ in 0..<64 {
            guard offset <= size-8 else { throw InstallerError("Truncated archive block.") }
            let block = try read(file, at: offset, count: 8)
            let kind = try block.uint16(0), length = UInt64(try block.uint32(4))
            offset += 8
            guard length <= size-offset else { throw InstallerError("Invalid archive block length.") }
            if kind == 0x143a {
                guard list == nil, length >= 5 else { throw InstallerError("Invalid archive file list.") }
                let expected = UInt64(try read(file, at: offset, count: 4).uint32(0))
                guard expected > 0, expected <= 10_000_000 else { throw InstallerError("Archive file list is too large.") }
                let temporary = scratch.appendingPathComponent("file-list-\(UUID().uuidString)")
                defer { try? FileManager.default.removeItem(at: temporary) }
                try extractStream(file, offset: offset+4, packed: length-4, size: expected, to: temporary)
                list = try Data(contentsOf: temporary)
            }
            if kind == 0x7f7f {
                // Unlike the metadata blocks, this length excludes the repeated 4-byte data length.
                guard offset <= size-4, length <= size-offset-4 else { throw InstallerError("Invalid archive data block.") }
                dataOffset = offset+4; dataLength = length; break
            }
            offset += length
        }
        guard let foundList = list, let foundOffset = dataOffset, let foundSize = dataLength else {
            throw InstallerError("Missing archive data or file list.")
        }
        dataStart = foundOffset
        entries = try parseEntries(foundList, dataSize: foundSize)
    }
    deinit { try? file.close() }
}

struct GameLocation {
    let root: URL
    var app: URL { root.appendingPathComponent("Medieval II Total War.app") }
    var mods: URL { root.appendingPathComponent("Medieval2Data/mods") }
    var target: URL { mods.appendingPathComponent(Constants.modName) }
    init(_ selected: URL, fixture: Bool = false) throws {
        let resolved = selected.resolvingSymlinksInPath().standardizedFileURL
        root = resolved.pathExtension.lowercased() == "app" ? resolved.deletingLastPathComponent() : resolved
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.appendingPathComponent("Medieval2Data/mods").path) else {
            throw InstallerError("Choose the Medieval II Total War folder containing Medieval2Data and the Mac game app.")
        }
        if fixture {
            guard fm.fileExists(atPath: root.appendingPathComponent(".third-age-test-fixture").path) else {
                throw InstallerError("Test installation requires a marked disposable fixture.")
            }
        } else {
            let app = root.appendingPathComponent("Medieval II Total War.app")
            guard let bundle = Bundle(url: app), bundle.bundleIdentifier == "com.feralinteractive.medieval2",
                  let executable = bundle.executableURL, fm.isExecutableFile(atPath: executable.path) else {
                throw InstallerError("This is not the native Feral Mac version of Medieval II. Windows installations are not supported.")
            }
            guard ["americas","british_isles","crusades","teutonic"].contains(where: {
                fm.fileExists(atPath: root.appendingPathComponent("Medieval2Data/mods/\($0)/data").path)
            }) else { throw InstallerError("Install the Kingdoms content for Medieval II first, then choose the game folder again.") }
        }
    }
    var installed: Bool {
        FileManager.default.fileExists(atPath: target.appendingPathComponent("data/world/maps/campaign/imperial_campaign/descr_strat.txt").path)
    }
}

func detectGames() -> [GameLocation] {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let steam = home.appendingPathComponent("Library/Application Support/Steam")
    var libraries = [steam]
    let vdf = steam.appendingPathComponent("steamapps/libraryfolders.vdf")
    if let content = try? String(contentsOf: vdf),
       let expression = try? NSRegularExpression(pattern: #""path"\s*"([^"]+)""#) {
        for match in expression.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
            if let range = Range(match.range(at: 1), in: content) {
                libraries.append(URL(fileURLWithPath: String(content[range]).replacingOccurrences(of: "\\\\", with: "\\")))
            }
        }
    }
    var seen = Set<String>()
    return libraries.compactMap { library in
        let url = library.appendingPathComponent("steamapps/common/Medieval II Total War")
        guard let game = try? GameLocation(url), seen.insert(game.root.path).inserted else { return nil }
        return game
    }
}

struct InstallReport: Codable {
    let helperVersion: String
    let installedAt: Date
    let archiveSHA256: [String]
    let publisherFilesVerified: Int
    let fileCount: Int
    let adjustments: [String]
}

final class Installer {
    let fm = FileManager.default
    func install(game: GameLocation, downloads: [URL], progress: @escaping (Double, String) -> Void) throws -> InstallReport {
        guard downloads.count == 2 else { throw InstallerError("Select both Third Age installer downloads.") }
        guard !fm.fileExists(atPath: game.target.path) else {
            throw InstallerError("Third Age is already present in this game folder. This helper will not replace it. Use Play Third Age, or choose a separate game installation for testing.")
        }
        guard fm.isWritableFile(atPath: game.mods.path) else { throw InstallerError("This game folder is not writable. Choose a Steam library you can write to.") }
        let disk = try fm.attributesOfFileSystem(forPath: game.mods.path)
        guard (disk[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0 >= 10_000_000_000 else {
            throw InstallerError("At least 10 GB of free space is needed on the game’s drive.")
        }
        try checkCancelled()
        let scratch = game.mods.appendingPathComponent(".third-age-install-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: scratch, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: scratch) }
        let stage = scratch.appendingPathComponent(Constants.modName)
        try fm.createDirectory(at: stage, withIntermediateDirectories: false)
        var archives: [Archive] = []
        for (index, url) in downloads.enumerated() {
            archives.append(try Archive(url: url, scratch: scratch) { fraction, message in
                progress(0.12*(Double(index)+fraction),message)
            })
        }
        guard Set(archives.map(\.number)) == Set([1,2]) else { throw InstallerError("Both selected files are the same part. Select part 1 and part 2.") }
        archives.sort { $0.number < $1.number }
        let total = archives.flatMap(\.entries).reduce(UInt64(0)) { $0+$1.size }
        var completed: UInt64 = 0, verified = 0
        let expectedOverlay: Set<String> = ["verify/icon.ico","verify/quicksfv.exe","verify/quicksfv.ini","verify/quicksfv.md5"]
        for archive in archives {
            for (i, entry) in archive.entries.enumerated() {
                try checkCancelled()
                let target = stage.appendingPathComponent(entry.path)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: target.path) {
                    guard archive.number == 2, expectedOverlay.contains(entry.path) else {
                        throw InstallerError("Unexpected overlap between archive parts: \(entry.path)")
                    }
                    try fm.removeItem(at: target)
                }
                try extractStream(archive.file, offset: archive.dataStart+entry.offset, packed: entry.packed, size: entry.size, to: target)
                completed += entry.size
                if i % 30 == 0 || i == archive.entries.count-1 {
                    progress(0.24+0.58*Double(completed)/Double(total),"Extracting part \(archive.number) of 2 · \(i+1) / \(archive.entries.count) files")
                }
            }
            progress(archive.number == 1 ? 0.67 : 0.84,"Verifying extracted files from part \(archive.number)…")
            verified += try verifyPublisherFiles(stage)
        }
        try checkCancelled()
        progress(0.94,"Preparing Third Age for the Mac game…")
        let changes = try configure(stage)
        var fileCount = 0
        if let enumerator = fm.enumerator(at: stage, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in enumerator where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { fileCount += 1 }
        }
        let report = InstallReport(helperVersion: Constants.version, installedAt: Date(),
            archiveSHA256: Constants.archives.sorted { $0.value.0 < $1.value.0 }.map(\.key),
            publisherFilesVerified: verified, fileCount: fileCount,
            adjustments: changes)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: stage.appendingPathComponent("mac-installation.json"), options: .atomic)
        try checkCancelled()
        guard !fm.fileExists(atPath: game.target.path) else { throw InstallerError("Third Age appeared in the destination during installation. The existing folder has been preserved.") }
        // Same-volume move only after all data verification succeeds. No existing mod is replaced.
        try fm.moveItem(at: stage, to: game.target)
        progress(1,"Third Age is installed. You can play now.")
        return report
    }

    func verifyPublisherFiles(_ stage: URL) throws -> Int {
        let manifest = try String(contentsOf: stage.appendingPathComponent("verify/quicksfv.md5"), encoding: .windowsCP1252)
        var count = 0
        for line in manifest.components(separatedBy: .newlines) where !line.isEmpty && !line.hasPrefix(";") {
            try checkCancelled()
            guard let separator = line.range(of: " *") else { throw InstallerError("Invalid publisher checksum list.") }
            let digest = String(line[..<separator.lowerBound]).lowercased()
            let fileName = String(line[separator.upperBound...]).replacingOccurrences(of: "\\", with: "/")
            guard fileName.hasPrefix("../"), digest.count <= 32, !digest.isEmpty,
                  digest.allSatisfy({ $0.isHexDigit }) else { throw InstallerError("Invalid publisher checksum entry.") }
            let relative = try relativePath(Constants.prefix+fileName.dropFirst(3))
            let file = try FileHandle(forReadingFrom: stage.appendingPathComponent(relative))
            defer { try? file.close() }
            var hasher = Insecure.MD5()
            while let bytes = try file.read(upToCount: 1_048_576), !bytes.isEmpty { try checkCancelled(); hasher.update(data: bytes) }
            let found = hasher.finalize().map { String(format: "%02x",$0) }.joined()
            guard found == String(repeating: "0", count: 32-digest.count)+digest else {
                throw InstallerError("Extracted file failed verification: \(relative). Installation was stopped.")
            }
            count += 1
        }
        guard count > 0 else { throw InstallerError("Publisher checksum list is empty.") }
        return count
    }

    func configure(_ stage: URL) throws -> [String] {
        var removed: [String] = []
        let enumerator = fm.enumerator(at: stage.appendingPathComponent("data"), includingPropertiesForKeys: [.fileSizeKey])
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let audioCache = url.deletingLastPathComponent().lastPathComponent == "sounds" &&
                ["dat","idx"].contains(url.pathExtension) && [0,24].contains(values.fileSize ?? -1)
            if url.lastPathComponent == "map.rwm" || audioCache {
                removed.append(String(url.path.dropFirst(stage.path.count+1)))
                try fm.removeItem(at: url)
            }
        }
        var config = try String(contentsOf:stage.appendingPathComponent("configuration.cfg"),encoding:.windowsCP1252)
        config = config.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"mods/Third_Age_3",with:"mods/third_age_3")
        for (pattern,replacement) in [
            (#"(?m)^movies\s*=\s*1"#,"movies = 0"),
            (#"(?m)^event_movies\s*=\s*1"#,"event_movies = 0"),
            (#"(?m)^no_background_fmv\s*=\s*0"#,"no_background_fmv = 1"),
            (#"(?m)^to\s*=\s*system.log.txt"#,"to = mods/third_age_3/system.log.txt"),
            (#"(?m)^level\s*=\s*\* trace"#,"level = * error")
        ] { config = config.replacingOccurrences(of:pattern,with:replacement,options:.regularExpression) }
        try config.write(to: stage.appendingPathComponent("default.cfg"),atomically:true,encoding:.utf8)
        for name in ["saves","preferences","logs"] { try fm.createDirectory(at: stage.appendingPathComponent(name), withIntermediateDirectories: true) }
        return ["Lowercase asset paths","Added native default.cfg; requested movie skipping","Removed rebuildable map/audio caches: "+removed.joined(separator: ", ")]
    }
}
