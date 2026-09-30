# Improvements to consider after the first beta

These are priorities for discussion, not promises or changes to Third Age's gameplay.

## Improve access first

1. **Clear setup and version selection.** Gigantus's guide describes the historical Steam installation problems; comments on the original mod page still report confusion over packages and launch steps. The helper verifies the supported two-part compilation and includes a short Mac guide.
2. **Reliable launch and switching.** Test Feral launcher arguments across Macs, then improve switching between Third Age, the base game, and other mods. A shared launcher setting must never silently leave the wrong mod selected.
3. **Clear first-load feedback.** Explain that the game rebuilds caches. The helper should not pretend it can measure game-loading progress unless it can actually observe it.
4. **Custom settlement guidance.** The original mod team recommends 1-vs-1 custom battles for most custom settlements. Document the limitation and reproduce individual failures before attempting map or script edits.
5. **Easier trust and installation.** Developer ID signing and Apple notarization would remove an obstacle for less technical players. This requires the maintainer's Apple Developer identity.

Sources: [Gigantus's installation guide](https://steamcommunity.com/sharedfiles/filedetails/?id=863223393), [original mod page and known issues](https://www.moddb.com/mods/third-age-total-war).

## Gameplay changes need separate evidence

Campaign pacing, scripted reinforcement armies, faction asymmetry, recruitment, and siege behavior are useful playtest questions. Reports about Divide and Conquer, Reforged, or Extended must not be treated as demonstrated bugs in this exact Third Age 3.2 package.

If a reproducible issue is confirmed, develop a separately versioned, optional patch with a plain description of changed files, an uninstall path, and save-compatibility guidance. Keep the original 3.2 experience available. Do not remove all reinforcement scripts or flatten faction differences merely because they feel difficult in one campaign.

Candidate playtest questions:

- Do reinforcement triggers feel understandable and finite in the tested faction's campaign?
- Do recruitment times create meaningful choices or only waiting?
- Does autoresolve repeatedly contradict comparable played battles?
- Which exact settlement, army composition, and entry point reproduce a siege problem?

Collect saves privately only when necessary and with the player's permission. Test changes in a separate mod folder before offering them to existing campaigns.
