# iw7-mods

Mods and scripts for Call of Duty: Infinite Warfare, made for [iw7-mod](https://github.com/auroramod/iw7-mod).

## Downloads

The downloads are on the [releases page](https://github.com/Josu-A/iw7-mods/releases), and they're always up to date.

### Mods

Extract the zip into a `mods` folder inside the game's folder, then load the mod from the Mods menu.

| Mod | What it does |
| --- | --- |
| [Rave Barriers](https://github.com/Josu-A/iw7-mods/releases/download/mods-latest/rave_barriers.zip) | Restores the cut Rave Vision barriers and fires in Rave in the Redwoods, with a custom barrier effect that cycles through the colour spectrum. |
| [Slasher Scares](https://github.com/Josu-A/iw7-mods/releases/download/mods-latest/slasher_scares.zip) | Restores the cut Slasher scares in Rave in the Redwoods: at 5 spots, a Slasher walks past players outside Rave Vision once they come near and look that way, then vanishes in his teleport effect. |

### Scripts

Extract the zip into the `iw7-mod` folder inside the game's folder. The script loads on the next map.

| Script | What it does |
| --- | --- |
| [Slasher block fix](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/slasher_block_fix.zip) | Fixes the Slasher's block in Rave in the Redwoods, which is meant to cut non-Smiley damage to 10% but never does. |
| [Slasher ground pound](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/slasher_ground_pound.zip) | Restores the Slasher's ground pound in Rave in the Redwoods, an attack the game has but never uses. |
| [Kendall wall buy](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/kendall_wall_buy.zip) | Restores the free Kendall 44 wall buy in Rave in the Redwoods' spawn room, which the game places but never turns on. |
| [Rave spawner fix](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/rave_spawner_fix.zip) | Fixes 4 zombie spawn points in Rave in the Redwoods that drop under the map, where their zombies die straight away and count as kills. |
| [Health bar](https://github.com/Josu-A/iw7-mods/releases/download/scripts-latest/health_bar.zip) | Shows your health as a bar and as `current / max` above the candy perks in Zombies. On by default; `set healthbar 0` in the console hides it. |

## Layout

| Folder | Contents |
| --- | --- |
| `mods/` | One folder per mod, as iw7-mod loads it. |
| `custom_scripts/` | Loose game scripts. Those named `dev_*` are for testing and aren't released. |
| `ui_scripts/` | One folder per UI script. A folder named after a game script is released in that script's zip. |
| `zonetool/`, `zone_source/` | What [x64-zt](https://github.com/Joelrau/x64-zt) builds a mod's fastfile from. |
| `vfx/` | The generator for the Rave Barriers effect, and the game effects it's built from. |

## Build

A mod's fastfile is built with [x64-zt](https://github.com/Joelrau/x64-zt) from its list in `zone_source/` and its assets in `zonetool/`.

1. Put x64-zt's `zonetool.exe` in the game's folder. It picks the game from the folder it runs in.
2. Copy or link `zonetool/` and `zone_source/` into the same folder.
3. Run `zonetool.exe` and enter `buildzone <name>`.
4. Copy the `<name>.ff` it writes there to the mod's folder as `mod.ff`.
