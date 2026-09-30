# Third Age for Mac

A free, unofficial Mac installation helper for **Third Age: Total War 3.2**.

**[Download the Mac beta](https://github.com/brianbmcintosh/third-age-mac-installer/releases)** · **[Report a problem](https://github.com/brianbmcintosh/third-age-mac-installer/issues)**

Choose your native Mac Steam installation of Medieval II, select the two supported Third Age downloads, and install. The helper extracts the mod's data directly; it never executes the Windows installers. It includes no game or mod assets.

## Status: 0.1.0 beta 1

- Universal app: Apple Silicon and Intel binaries, deployment target macOS 12 or later.
- A manual installation using this approach was reported working by an Apple Silicon player.
- Automated clean-folder installation uses the full real archives and verifies 18,961 publisher file checksums.
- Intel compilation is supported; Intel gameplay and older macOS versions still need community testing.
- This build is **not Developer ID signed or notarized**. It has a local ad-hoc code signature. See the opening instructions below.
- Campaign balancing, custom maps, and mod scripts remain Third Age 3.2's original content.

## Requirements

- Your own native **Mac Steam copy of Medieval II: Total War with Kingdoms** installed and launched at least once.
- Steam installed and signed in.
- 10 GB free on the game's drive, in addition to the downloaded installers.
- These exact two files from [Gigantus's full 3.2 compilation](https://steamcommunity.com/sharedfiles/filedetails/?id=863223393):
  - `TATW 3.2 part 1 of 2.exe` — 1,835,183,234 bytes.
  - `TATW 3.2 part 2 of 2.exe` — 2,059,165,989 bytes.

The original 3.0 installers, standalone 3.2 patch, Divide and Conquer, and Reforged use different packages and are not supported by this helper. Download links are maintained on Gigantus's guide and the linked Total War Center page. Renaming a different download will not make it compatible.

## Install and play

1. Download the helper release ZIP and unzip it.
2. Move **Third Age for Mac.app** to your Applications folder. A folder named `Applications` inside your home folder works too.
3. Open the helper. For this unnotarized beta, macOS may ask you to review it in **System Settings → Privacy & Security → Open Anyway** after the first opening attempt. Use that per-app action only if you trust the source. No global security changes are needed.
4. Check the detected game folder. For another Steam library, click **Choose…** and select `steamapps/common/Medieval II Total War`.
5. Click **Select files…**, hold Command, and select both installer files.
6. Click **Install Third Age** and wait for verification to finish. Cancel removes the temporary installation.
7. Open Steam and sign in. Quit Medieval II completely if it is already running.
8. Click **Play Third Age**, then **Play** in the Feral game launcher.
9. Choose a new single-player campaign. The first load can take longer while the Mac creates its map and audio caches.

The helper can create a Desktop alias using **Desktop shortcut**. Keep the app in a stable location before doing so.

### If the base game opens

Quit Medieval II completely. Open its launcher, choose **Advanced**, enable **Advanced Options**, and enter:

```text
--features.mod=mods/third_age_3
```

Click **Play**. For other mods or the original game, disable that Advanced Options override before using their shortcuts. The helper detects an enabled override that names another mod and explains how to clear it.

## What the helper changes

- Adds `Medieval2Data/mods/third_age_3` to the selected game installation.
- Converts extracted asset paths to lowercase and adds a Mac `default.cfg` based on the supplied settings.
- Removes packaged map caches and empty sound caches so the native game can rebuild them.
- Requests movie skipping in that configuration; Windows BIK cutscenes are not converted to Mac video formats. Movie behavior is not fully validated.
- Records an installation receipt inside the new mod folder.
- Remembers the selected game folder in the helper's own preferences.

An existing `third_age_3` folder is refused, not overwritten. The helper does not alter other mod folders, the base game's files, saved campaigns, Steam launch settings, or Feral's global preferences. It extracts into a unique temporary directory and publishes the mod folder only after verification passes. An unexpected app or system shutdown may leave a `.third-age-install-…` temporary folder; this can be removed after the helper is closed.

## Troubleshooting and limits

| Symptom | What to do |
| --- | --- |
| Download rejected | Use the exact two-part Gigantus compilation above; compare its sizes and SHA-256 checksums below. |
| Already installed | Use Play Third Age. Existing installations are not upgraded or replaced by this beta. |
| Game folder not recognized | Select the Mac Steam game folder, with the game app and Medieval2Data alongside each other. Install Kingdoms content first. |
| Can't write to game folder | Choose a Steam library your Mac account can write to. The helper does not request administrator access. |
| Game already running | Quit Medieval II fully, then launch the desired mod. |
| First campaign load is slow | Allow the first map/audio cache build to finish. |
| Custom settlement battle issues | The mod team recommends 1-vs-1 custom battles for most custom settlements. See the [original known issues](https://www.moddb.com/mods/third-age-total-war). |

This beta has no updater, telemetry, account system, or network downloader. The Download and Help links open only when selected. It requires no Python, Homebrew, Wine, or Windows on the player's Mac.

## Supported archive checksums

```text
3a827ff091541d9325f4852c1c63966e1bf1be6f7459d2b088a9c98e32a9fc0e  TATW 3.2 part 1 of 2.exe
2970d57990632eaf2c7fb348bd32e730424314fb44de7ecad4b78765d859c168  TATW 3.2 part 2 of 2.exe
```

These identify the exact downloads used for testing, not a new signature from the mod's publisher. The helper also checks the publisher's bundled file checksums after extraction.

## Build from source

Developers need Apple's Command Line Tools and Python 3 for the build script. Players do not.

```sh
python3 build.py
```

This produces `.build/Third Age for Mac.app`, with both architectures and an ad-hoc signature. For an Apple Silicon-only development build:

```sh
python3 build.py --arch arm64
```

To use your own Developer ID identity:

```sh
python3 build.py --identity 'Developer ID Application: YOUR NAME (TEAMID)'
```

Notarization is a separate release step requiring the maintainer's Apple Developer credentials. Follow [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution); never commit credentials or signing certificates.

## Tests

```sh
python3 Tests/run_tests.py
python3 Tests/run_tests.py --archives '/path/to/TATW 3.2 part 1 of 2.exe' '/path/to/TATW 3.2 part 2 of 2.exe'
```

The integration test creates a disposable Steam-style folder, checks cancellation cleanup, installs the full mod, verifies publisher checksums, and proves an existing neighboring mod is unchanged. It then attempts a repeat install and confirms it is refused. It does not launch the game or use a real Steam library.

## Credits

- **Third Age: Total War team** — the original mod and all its assets. [ModDB](https://www.moddb.com/mods/third-age-total-war)
- **Gigantus** — the full 3.2 compilation and distribution guide.
- **William Engelmann / Bioruebe, cicdec** — Clickteam archive format reference, under BSD-3-Clause. [Source](https://github.com/Bioruebe/cicdec)
- Apple system zlib and bzip2 provide decompression; CryptoKit provides checksums.

The helper is unofficial and is not endorsed by the mod team, Feral Interactive, SEGA, Creative Assembly, Valve, or the Tolkien rightsholders. MIT covers the original helper code; see `THIRD_PARTY_NOTICES.txt` for the retained archive-reader notice. No permission to redistribute the game or mod assets is implied.

## Feedback

Please include Mac model/chip, macOS version, helper version, Steam library location type (internal/external drive), the exact error message, and whether installation, campaign, or battle failed. Do not upload saves or personal paths unless needed. See `Docs/TESTING.md` for the beta test checklist.
