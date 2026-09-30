import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var game: GameLocation?
    var downloads: [URL] = []
    var busy = false
    var progressValue = 0.0
    let gameLabel = NSTextField(wrappingLabelWithString: "Looking for your Steam installation…")
    let filesLabel = NSTextField(wrappingLabelWithString: "Select the two TATW 3.2 installer downloads.")
    let statusLabel = NSTextField(wrappingLabelWithString: "Your existing campaigns, saves, and other mods stay in place.")
    let progressBar = NSProgressIndicator()
    var installButton: NSButton!
    var playButton: NSButton!
    var chooseGameButton: NSButton!
    var chooseFilesButton: NSButton!
    var cancelButton: NSButton!
    var shortcutButton: NSButton!

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMenu()
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:740,height:690),
            styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Third Age for Mac"
        window.delegate = self
        window.center()
        buildUI()
        if let path = UserDefaults.standard.string(forKey: "gamePath"), let saved = try? GameLocation(URL(fileURLWithPath:path)) { game = saved }
        else { game = detectGames().first }
        refresh()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps:true)
    }

    func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title:title,target:self,action:action);b.bezelStyle = .rounded
        return b
    }
    func text(_ value: String, size: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString:value)
        label.font = .systemFont(ofSize:size,weight:weight)
        return label
    }
    func row(_ number: String, _ title: String, _ detail: NSTextField, _ action: NSButton) -> NSView {
        let box = NSBox();box.boxType = .custom
        box.cornerRadius = 10;box.borderColor = .separatorColor;box.fillColor = .controlBackgroundColor
        let badge = text(number,size:18,weight:.semibold);badge.textColor = .systemBrown
        let heading = text(title,size:15,weight:.semibold)
        detail.font = .systemFont(ofSize:12);detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 3
        let labels = NSStackView(views:[heading,detail]);labels.orientation = .vertical;labels.alignment = .leading;labels.spacing = 7
        let stack = NSStackView(views:[badge,labels,action]);stack.orientation = .horizontal;stack.alignment = .centerY;stack.spacing = 18
        box.addSubview(stack);stack.translatesAutoresizingMaskIntoConstraints = false
        badge.setContentHuggingPriority(.required,for:.horizontal)
        action.setContentHuggingPriority(.required,for:.horizontal)
        action.setContentCompressionResistancePriority(.required,for:.horizontal)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo:box.leadingAnchor,constant:18),
            stack.trailingAnchor.constraint(equalTo:box.trailingAnchor,constant:-18),
            stack.topAnchor.constraint(equalTo:box.topAnchor,constant:16),
            stack.bottomAnchor.constraint(equalTo:box.bottomAnchor,constant:-16),
            box.heightAnchor.constraint(greaterThanOrEqualToConstant:100)
        ])
        return box
    }
    func buildUI() {
        guard let content = window.contentView else { return }
        let eyebrow = text("UNOFFICIAL COMMUNITY HELPER  ·  BETA",size:10,weight:.bold)
        eyebrow.textColor = .systemBrown
        let title = text("Middle-earth, on your Mac.",size:29,weight:.bold)
        let subtitle = text("Install Third Age: Total War 3.2 into your Mac copy of Medieval II.")
        subtitle.textColor = .secondaryLabelColor
        let header = NSStackView(views:[eyebrow,title,subtitle]);header.orientation = .vertical;header.alignment = .leading;header.spacing = 8

        chooseGameButton = button("Choose…",#selector(chooseGame))
        chooseFilesButton = button("Select files…",#selector(chooseFiles))
        let gameRow = row("1","Find your game",gameLabel,chooseGameButton)
        let filesRow = row("2","Choose the Third Age downloads",filesLabel,chooseFilesButton)
        let downloadButton = button("Get the two downloads ↗",#selector(openDownloads))
        let downloadNote = text("Use Gigantus’s two-part 3.2 compilation. The original 3.0 installers are different.",size:11)
        downloadNote.textColor = .secondaryLabelColor
        let downloadRow = NSStackView(views:[downloadButton,downloadNote]);downloadRow.spacing = 12;downloadRow.alignment = .centerY

        progressBar.style = .bar;progressBar.isIndeterminate = false;progressBar.minValue = 0;progressBar.maxValue = 1
        statusLabel.font = .systemFont(ofSize:13);statusLabel.maximumNumberOfLines = 4
        installButton = button("Install Third Age",#selector(install))
        installButton.keyEquivalent = "\r"
        playButton = button("Play Third Age",#selector(play))
        cancelButton = button("Cancel",#selector(cancel));cancelButton.isHidden = true
        let actions = NSStackView(views:[installButton,playButton,cancelButton]);actions.spacing = 12
        let note = text("Requires the native Mac Steam game with Kingdoms and 10 GB free.\nThe helper includes no game or mod assets. Intel gameplay is not yet tested.",size:11)
        note.textColor = .secondaryLabelColor
        shortcutButton = button("Desktop shortcut",#selector(createShortcut))
        let helpButton = button("Help & credits",#selector(help))
        let footer = NSStackView(views:[shortcutButton,helpButton]);footer.spacing = 10
        let stack = NSStackView(views:[header,gameRow,filesRow,downloadRow,progressBar,statusLabel,actions,note,footer])
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing = 19
        content.addSubview(stack);stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:30),
            stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-30),
            stack.topAnchor.constraint(equalTo:content.topAnchor,constant:27),
            stack.bottomAnchor.constraint(lessThanOrEqualTo:content.bottomAnchor,constant:-23),
            gameRow.widthAnchor.constraint(equalTo:stack.widthAnchor),
            filesRow.widthAnchor.constraint(equalTo:stack.widthAnchor),
            progressBar.widthAnchor.constraint(equalTo:stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo:stack.widthAnchor),
            downloadRow.widthAnchor.constraint(equalTo:stack.widthAnchor)
        ])
    }
    func refresh() {
        if let game {
            gameLabel.stringValue = (game.installed ? "Third Age is already installed.\n" : "Mac game found.\n")+game.root.path
            gameLabel.toolTip = game.root.path
        } else { gameLabel.stringValue = "Choose the Medieval II Total War folder in your Steam library." }
        installButton.isEnabled = !busy && game != nil && downloads.count == 2 && !(game?.installed ?? false)
        playButton.isEnabled = !busy && (game?.installed ?? false)
        chooseGameButton.isEnabled = !busy;chooseFilesButton.isEnabled = !busy
        shortcutButton.isEnabled = !busy
        cancelButton.isHidden = !busy
        cancelButton.isEnabled = busy
    }
    func alert(_ title: String, _ message: String) {
        let alert = NSAlert();alert.messageText = title;alert.informativeText = message
        alert.addButton(withTitle:"OK");alert.beginSheetModal(for:window)
    }
    @objc func chooseGame() {
        let panel = NSOpenPanel();panel.canChooseFiles = false;panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true;panel.prompt = "Use game folder"
        panel.message = "Choose Medieval II Total War inside steamapps/common. You can also select its Mac app."
        if let game { panel.directoryURL = game.root }
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do { self.game = try GameLocation(url);UserDefaults.standard.set(self.game?.root.path,forKey:"gamePath");self.refresh() }
            catch { self.alert("Game folder not recognized",error.localizedDescription) }
        }
    }
    @objc func chooseFiles() {
        let panel = NSOpenPanel();panel.canChooseFiles = true;panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true;panel.allowedContentTypes = [UTType(filenameExtension:"exe") ?? .data];panel.prompt = "Use downloads"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        panel.message = "Select part 1 and part 2 together. Their contents will be checked before installation."
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self,response == .OK else { return }
            guard panel.urls.count == 2 else { self.alert("Select both parts","Hold Command and select both TATW 3.2 installer files.");return }
            self.downloads = panel.urls
            self.filesLabel.stringValue = panel.urls.map(\.lastPathComponent).joined(separator:"\n")
            self.refresh()
        }
    }
    @objc func openDownloads() { NSWorkspace.shared.open(URL(string:Constants.downloadPage)!) }
    @objc func install() {
        guard let game,!busy else { return }
        busy = true;progressValue = 0;progressBar.doubleValue = 0;ta_set_cancelled(0);refresh()
        let selected = downloads
        DispatchQueue.global(qos:.userInitiated).async {
            do {
                _ = try Installer().install(game:game,downloads:selected) { value,message in
                    DispatchQueue.main.async { self.progressValue = max(self.progressValue,value);self.progressBar.doubleValue = self.progressValue;self.statusLabel.stringValue = message }
                }
                DispatchQueue.main.async {
                    self.busy = false;UserDefaults.standard.set(game.root.path,forKey:"gamePath");self.refresh()
                    self.statusLabel.stringValue = "Installed and verified. Open Steam, then choose Play Third Age. The first campaign load can take longer."
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false;self.refresh();self.statusLabel.stringValue = error.localizedDescription
                    self.alert("Installation stopped",error.localizedDescription)
                }
            }
        }
    }
    @objc func cancel() { ta_set_cancelled(1);statusLabel.stringValue = "Cancelling and removing temporary files…";cancelButton.isEnabled = false }

    @objc func play() {
        guard let game,game.installed else { return }
        guard NSRunningApplication.runningApplications(withBundleIdentifier:"com.feralinteractive.medieval2").isEmpty else {
            alert("Quit Medieval II first","Quit the game completely before choosing a different mod, then click Play Third Age again.");return
        }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier:"com.valvesoftware.steam").isEmpty else {
            if let steam = NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.valvesoftware.steam") {
                NSWorkspace.shared.openApplication(at:steam,configuration:NSWorkspace.OpenConfiguration()) { _,_ in }
            }
            alert("Open Steam first","Sign in to Steam and let it finish starting, then click Play Third Age again.");return
        }
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Feral Interactive/Medieval II Total War/Preferences Data")
        if let xml = try? String(contentsOf:preferences),
           xml.range(of:#"<value name="ExtraCommandLineEnabled" type="integer">1</value>"#) != nil,
           let regex = try? NSRegularExpression(pattern:#"<value name="ExtraCommandLine" type="string">([^<]*)</value>"#),
           let match = regex.firstMatch(in:xml,range:NSRange(xml.startIndex...,in:xml)),
           let range = Range(match.range(at:1),in:xml),
           xml[range].contains("features.mod"), !xml[range].contains("features.mod=mods/third_age_3") {
            alert("Another mod is selected in Advanced Options","In Medieval II’s launcher, turn off Advanced Options, quit the launcher, then click Play Third Age here again. Help & credits includes the manual launch option.");return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--features.mod=mods/third_age_3"]
        config.activates = true
        NSWorkspace.shared.openApplication(at:game.app,configuration:config) { _,error in
            DispatchQueue.main.async {
                if let error { self.alert("Could not open Medieval II",error.localizedDescription) }
                else { self.statusLabel.stringValue = "Click Play in the Medieval II launcher. If the base game appears, Help & credits explains how to select Third Age in Advanced Options." }
            }
        }
    }
    @objc func createShortcut() {
        let source = Bundle.main.bundleURL
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Third Age for Mac.app")
        guard !FileManager.default.fileExists(atPath:desktop.path) else { alert("Shortcut already exists","The existing Desktop item has been kept.");return }
        do {
            let bookmark = try source.bookmarkData(options:.suitableForBookmarkFile,includingResourceValuesForKeys:nil,relativeTo:nil)
            try URL.writeBookmarkData(bookmark,to:desktop)
            alert("Shortcut created","Third Age for Mac is now on your Desktop. Keep the helper app in Applications so it remains easy to find.")
        } catch { alert("Could not create shortcut",error.localizedDescription) }
    }
    @objc func help() {
        if let file = Bundle.main.url(forResource:"Start Here",withExtension:"html") { NSWorkspace.shared.open(file) }
    }
    func createMenu() {
        let menu = NSMenu();let root = NSMenuItem();let appMenu = NSMenu()
        let help = NSMenuItem(title:"Help & credits",action:#selector(self.help),keyEquivalent:"?");help.target = self
        appMenu.addItem(help);appMenu.addItem(.separator())
        appMenu.addItem(withTitle:"Quit Third Age for Mac",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        root.submenu = appMenu;menu.addItem(root)
        let edit = NSMenuItem();edit.title = "Edit";let editMenu = NSMenu(title:"Edit")
        editMenu.addItem(withTitle:"Copy",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
        editMenu.addItem(withTitle:"Paste",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
        editMenu.addItem(withTitle:"Select All",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
        edit.submenu = editMenu;menu.addItem(edit)
        NSApplication.shared.mainMenu = menu
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if busy { alert("Installation is running","Use Cancel and wait for cleanup before closing the helper.");return false }
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { alert("Installation is running","Use Cancel and wait for cleanup before quitting the helper.");return .terminateCancel }
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct ThirdAgeApp {
    static func main() {
        let app = NSApplication.shared;app.setActivationPolicy(.regular)
        let delegate = AppDelegate();app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
