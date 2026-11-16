# iw7-mods

Mods and scripts for Call of Duty: Infinite Warfare, made for [iw7-mod](https://github.com/auroramod/iw7-mod).

## Downloads

The downloads are on the [releases page](https://github.com/Josu-A/iw7-mods/releases), and they're always up to date.

### Mods

Extract the zip into a `mods` folder inside the game's folder, then load the mod from the Mods menu.

| Mod | What it does |
| --- | --- |
| [Rave Barriers](https://github.com/Josu-A/iw7-mods/releases/download/mods-latest/rave_barriers.zip) | Restores the cut Rave Vision barriers and fires in Rave in the Redwoods, with a custom barrier effect that cycles through the colour spectrum. |

### Scripts

Extract the zip into the `iw7-mod` folder inside the game's folder. The script loads on the next map.

| Script | What it does |
| --- | --- |
| [Slasher block fix](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/slasher_block_fix.zip) | Fixes the Slasher's block in Rave in the Redwoods, which is meant to cut non-Smiley damage to 10% but never does. |

## Layout

| Folder | Contents |
| --- | --- |
| `mods/` | One folder per mod, as iw7-mod loads it. |
| `custom_scripts/` | Loose scripts. Those named `dev_*` are for testing and aren't released. |
| `zonetool/`, `zone_source/` | What [x64-zt](https://github.com/Joelrau/x64-zt) builds a mod's fastfile from. |
| `vfx/` | The generator for the Rave Barriers effect, and the game effects it's built from. |

## Build

A mod's fastfile is built with [x64-zt](https://github.com/Joelrau/x64-zt) from its list in `zone_source/` and its assets in `zonetool/`.

1. Put x64-zt's `zonetool.exe` in the game's folder. It picks the game from the folder it runs in.
2. Copy or link `zonetool/` and `zone_source/` into the same folder.
3. Run `zonetool.exe` and enter `buildzone <name>`.
4. Copy the `<name>.ff` it writes there to the mod's folder as `mod.ff`.
