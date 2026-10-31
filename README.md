# Shield-Kin

An original follower framework for Skyrim Special Edition, made for the Authoria modlist.
It uses Papyrus, one ESL-flagged plugin and a [Magelight UI](https://www.nexusmods.com/skyrimspecialedition/mods/193303) page. There is no custom DLL.

## Features

- Up to 30 followers. The vanilla "Follow me" dialogue works for any number of them.
- Orders: follow, wait, relax nearby, relax at a spot, go home, join camp. Close, normal or far follow distance.
- Combat: style (own, warrior, archer, mage, healer, tank), stance (balanced, aggressive, defensive, passive) and protection (mortal, protected, essential).
- Outfits: five sets (travel, town, home, sleep, combat) that change by place, or by hand.
- Homes and a party camp. Dismissed followers go to the Registry, keep their settings and live at their home.
- Catch-up teleport for followers left far behind.
- Optional levelling with the player, up to a share of the player's level.
- Selling: hand items to a follower and send them to the nearest merchant. Their Speech improves the price.
- Requiem: followers are registered with Requiem's follower control quest.

## Menu

Press **F7** (rebindable in Settings), or look at a follower and press F7 to open their page.
The menu can also be opened by asking a follower "Let's go over your orders."
Themes: Dark Vellum and Ink on Paper.

Open `Magelight/ShieldKin/index.html` in a browser to preview the menu with sample followers.

## Requirements

SKSE, PapyrusUtil, powerofthree's Papyrus Extender, Magelight UI.

## Layout

| Path | What |
| --- | --- |
| `Source/Scripts/` | Papyrus sources. `DialogueFollowerScript.psc` overrides the vanilla script so recruiting routes to Shield-Kin. |
| `Magelight/ShieldKin/` | Menu page (HTML, CSS, JS). Installs to `Data/Magelight/ShieldKin/`. |
| `esp/` | Record specs used to generate `Shield-Kin.esp` (quest, aliases, packages, dialogue). |
| `tools/enable-shieldkin.ps1` | Enables the mod in the Authoria MO2 profile and disables Horde, marth Follower Overhaul and Harbinger. |

## Building

Compile the scripts with the Creation Kit's `PapyrusCompiler.exe`, with the vanilla, SKSE, PapyrusUtil, Papyrus Extender and Magelight sources on the import path. Install as an MO2 mod:

```
Shield-Kin.esp
Scripts/*.pex
Source/Scripts/*.psc
Magelight/ShieldKin/{index.html, shieldkin.css, shieldkin.js}
```

Start a new game after installing.
