# Beta test record and checklist

## Recorded results — 0.1.0-beta.1

Test environment: Apple Silicon (arm64), macOS 26.3.1 (a), September 30, 2026.

- A manual installation using the same conversion approach was reported working by the local player. This was not a complete campaign compatibility test.
- Native decompression and parser tests passed, including truncated archives, size bounds, unsafe paths, duplicate output refusal, output symlink refusal, and cancellation.
- A full installation of both supported real archives passed in a disposable Steam-style folder whose path contains spaces.
- All 18,961 publisher checksum entries passed before Mac adjustments.
- The installed mod contained 18,951 files before adding its receipt.
- Cancellation after extraction began removed the temporary installation.
- A neighboring mod/save sentinel remained unchanged after cancellation, successful installation, and an attempted repeated installation.
- Repeated installation was refused and the existing receipt was preserved.
- Lowercase asset paths, the Mac default.cfg, and cache removal passed inspection.

The fixture tests do not launch Medieval II, emulate its engine, or establish campaign compatibility. The compiled Intel binary still needs runtime testing on an Intel Mac.

## Community test checklist

Use a backed-up game installation for beta testing. Existing Third Age installations cannot be replaced by this helper.

- [ ] Record Mac model/chip, macOS version, helper version, and internal/external drive.
- [ ] Open the distributed ZIP's app after normal browser download and macOS approval.
- [ ] Detect the default Steam library or select an alternate library.
- [ ] Select both supported downloads and complete installation.
- [ ] Open Help & credits; confirm the local guide appears.
- [ ] Launch with Steam open and Medieval II fully quit.
- [ ] Confirm the Third Age menu and campaign, including the Advanced Options fallback if needed.
- [ ] Start a new campaign; record faction and difficulty.
- [ ] End several turns, save, quit, and reload.
- [ ] Fight an open-field battle and a campaign siege; record settlement and factions.
- [ ] Check music, voices, UI text, and any movie-related failures.
- [ ] Try a 1-vs-1 custom settlement battle.
- [ ] Disable the launcher override and confirm the original game / other mods remain accessible.

Long campaigns, multiplayer, macOS 12–15, Intel runtime behavior, case-sensitive volumes, and all custom settlements are unverified. Add dated observations rather than changing these to “supported” based on compilation alone.

## Reporting

Describe the exact steps and the first error. Distinguish the helper failing to install from the game failing after launch. Include the installation receipt's helper version and checksum count if available. Keep personal paths and save files out of public reports unless they are necessary and you intend to share them.
