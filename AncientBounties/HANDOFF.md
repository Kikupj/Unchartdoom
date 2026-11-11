# Ancient Bounties — Handoff

Status as of 2026-11-10. Roguelite shooter on UZDoom + Freedoom, inspired by Uncharted.
**The game does not run yet.** The core scripts compile and the asset pipeline works, but the level generator is unfinished, the menus are stubs, and nothing has been played end to end.

Everything lives in `C:\Games\Unchartdoom\AncientBounties\`.

---

## 1. What exists

| Area | File(s) | State |
|---|---|---|
| Build pipeline | `tools/build.py` | Works. Imports packs → art → sfx → maps → copies `src/` → assembles root lumps → zips pk3. |
| Third-party import | `tools/import_packs.py` | Works. Pulls all 16 weapon packs, DeePaybackEnemies and TacticalDuckDodge from `_modding`. |
| Textures and skies | `tools/gen_art.py`, `tools/artlib.py` | Works. 46 textures, 6 skies. Reviewed on a contact sheet (`_dev/shots/tex.png`). |
| Sprites | `tools/gen_art_sprites.py` | Works. 73 sprites (`_dev/shots/spr.png`). |
| Sound effects | `tools/gen_sfx.py` | Runs and writes 32 WAVs. Never listened to. |
| Map engine | `tools/gridmap.py` | Works. Grid cells → UDMF WAD. One test map loaded and rendered in engine. |
| Level generator | `tools/gen_maps.py` | **Incomplete — see 2.1.** Never run. |
| Game data tables | `src/zscript/ab/00_data.zs` | Compiles. |
| Meta game (profile, camp, crew, rival, runs) | `10_game.zs` | Compiles. Never executed. |
| Level director and HUD | `20_level.zs` | Compiles. Never executed. |
| Player, loadout, dodge, medkit | `30_player.zs` | Compiles. Never executed. |
| Loot and spots | `40_items.zs` | Compiles. Never executed. |
| Puzzles and traps | `50_puzzle.zs` | Compiles. Never executed. |
| Enemy roster and spawning | `60_enemies.zs`, `src/lumps/decorate_ab.txt` | Compiles. Never executed. |
| Decor, stations, exit flare | `70_decor.zs` | Compiles. Never executed. |
| Menus | `80_menu.zs` | **Two empty stub classes.** |
| UI art | `tools/gen_art_ui.py` | **Empty stub.** |
| Lumps | `src/lumps/` (mapinfo, cvarinfo, keyconf, sndinfo, decorate_ab) | Written. MAPINFO loads. |

"Compiles" means UZDoom 5.0.3 loaded the full mod with `-norun` and reported no script errors. That was true before `gen_maps.py` was written; nothing after that point has been checked.

---

## 2. What has to be finished, in order

### 2.1 Finish `tools/gen_maps.py` (blocker)

The file ends after `Gen.pop_V`. It is missing its tail:

- `build_camp()` — the hub map `ABCAMP`. Planned: an oval jungle clearing at dusk, six structures as raised sectors (canvas/camo/crate textures), a map table, campfire, antenna, lanterns, four `AB_CrewNPC`, and eight `AB_Station` signposts. Station args are `(tab, sign frame)`. Planned mapping: COMMAND→tab 0, ARMORY→2, WORKSHOP→2, INFIRMARY→1, STORAGE→5, RADIO→4, EXPEDITION→3, ARCHIVE→5.
- `MAPS` list — `PE/EG/CA/NE` × (`A1–A3`, `P1–P3`, `V1`) plus `CIA1`, `CIA2`, `CIP1`, `CIV1`. 32 expedition maps.
- `make(name, code, kind)` — seed from `crc32(name)`, retry up to ~60 seeds on `RuntimeError`, reject action maps outside roughly 22–60 enemy spots.
- `main()` — write `maps/*.wad` and `_gen/mapinfo_maps.txt` (one `map` block each: `sky1`, `music`, `nointermission`, `next = "ABCAMP"`).

A full draft of this tail was written once but the command was too large to send, so it never landed on disk. Rewrite it in its own step.

Then run it and expect bugs. The generator is ~450 lines of untested layout code. Likely trouble spots:

- `spots()` returning fewer cells than asked, so puzzles do not fit (`add_puzzle` raises and the seed is retried — check it does not exhaust all seeds).
- `pop_V` assumes exactly 4 path rooms and that `path[2].gate` gates the vault.
- `pop_P` assumes 6 path rooms with gates on rooms 3 and 5.
- Door/gate texture alignment. The plan was to force `offsetx = 0` on lines touching a `kind='door'` sector in `gridmap.emit()`. Not implemented.
- The Citadel theme uses Freedoom texture names chosen by name only (`STARGR2`, `COMPSTA1`, `METAL2`, `CEMENT9`, `BIGDOOR2`, `BIGDOOR7`). Never looked at.

### 2.2 Write the menus (`80_menu.zs`)

Both are `GenericMenu` subclasses opened from `AB_Level.InterfaceProcess`. Each must set `menuactive = Menu.OnNoPause` in `Init`, otherwise the game pauses and network events from the menu never get processed.

**`AB_CampMenu`** — needs `void Open(int tab)` (tab −1 = keep last). Six tabs per the mockup: BASE CAMP, CREW, GEAR, MISSIONS, INTEL, ARCHIVE. It reads state from `AB_Game.Get()` (all the `clearscope` accessors are there) and acts only by `EventHandler.SendNetworkEvent`. Commands already handled in `AB_Game.NetworkProcess`:

| Command | Args | Does |
|---|---|---|
| `ab_upgrade` | building | Upgrade a building |
| `ab_buyw` / `ab_equip` | weapon | Buy / toggle loadout |
| `ab_buygear` | gear | Buy workshop gear |
| `ab_recruit` / `ab_dismiss` / `ab_partner` | candidate or crew index | Crew management |
| `ab_unlock` / `ab_sabotage` | region | Spend intel |
| `ab_dispatch` | region, crew bitmask | Send a team |
| `ab_wait` | — | Advance a day |
| `ab_launch` | region | Start an expedition |
| `ab_ack` | — | Dismiss the top report popup |
| `ab_reset`, `ab_cheat` | — | New profile / test resources |

It also has to show the report queue (`repTitle` / `repBody`) as popups and the feedback line (`toastText` / `toastTic`).

**`AB_ClearMenu`** — stage-clear screen. Shows the haul, three boon choices from `AB_Game.offer[]`, and an extract option. Sends `ab_boon` (0–2) or `ab_extract`. Must not be closable with Escape: the player is frozen and invulnerable until a choice is made.

### 2.3 UI art (`gen_art_ui.py`)

Nothing drawn yet. Needed: `TITLEPIC`, menu logo (`M_DOOM` replacement), world map for the MISSIONS tab, six building icons, resource icons. Fonts are available through `artlib.font('title' | 'body', size)` (both OFL, taken from `branding/source`). The planned world map was coarse continent polygons on parchment with a red travel line; region lon/lat are already in `AB.RegionLon` / `AB.RegionLat`.

### 2.4 First real playtest

Nothing below has ever run. Each needs to be watched working:

1. New game lands in `ABCAMP`; stations open the menu; profile persists in `ab_profile` across restarts.
2. Launch → loadout is given once → stage title card → enemies spawn from spots.
3. Each of the six puzzle types can be solved and opens its gate.
4. Exit flare → clear screen → boon → next stage with inventory carried.
5. Going down → fade → back at camp with the Storage percentage kept.
6. Vault: boss blocks the treasure, pickup triggers the ambush, flare arms.
7. Rival: days advance, Thorne claims a region, Citadel unlocks, finale returns lost treasures.
8. Crew dispatch resolves and reports.

### 2.5 Balance

All numbers are first guesses: enemy counts and tier odds, weapon prices, building costs, rival rates (focus region +4.5/day, others +1.2/day, −8 per stage cleared), dispatch odds. The DeePayback enemies fire fast tracers and may be far too lethal in groups.

### 2.6 Packaging

- `Play Ancient Bounties.bat` — not written. Should find `uzdoom.exe` and run `-iwad freedoom-0.13.0\freedoom2.wad -file AncientBounties\AncientBounties.pk3`.
- **There is no `uzdoom.exe` in the folder** — the root is the UZDoom source tree only. A Windows build is at `github.com/UZDoom/UZDoom/releases` (5.0.3 was current). Decide whether to download it or point the launcher at an existing install.
- `README.md` with controls and credits — not written. `build.py` already emits `CREDITS-THIRD-PARTY.txt` from the packs.
- Final pk3 has never been zipped. Expect ~45 MB.

---

## 3. Known issues and decisions already made

- **TacticalDuckDodge has a parse error as shipped** (`ZSCRIPT.zs` line 2375, `Class<Actor>(projType)`). The importer patches it to `((class<Actor>)(projType))` in the build copy only. The original in `_modding` is untouched and will not load on its own.
- **DeePaybackEnemies bundles voice clips ripped from commercial games** (see its `credits.txt`). Fine for private play; check before distributing.
- Enemies drop Doom weapons; `AB_Level.CheckReplacement` swaps those for ammo.
- The player never dies: `+BUDDHA`, and reaching 1 HP triggers "expedition failed". `PlayerDied` has a fallback.
- Profile is a `nosave` cvar, so loading an old savegame does not roll it back. `AB_Level` compares a stored run id and kicks stale saves to camp.
- ZScript classes cannot inherit from DECORATE ones, so the bosses (`AB_Thorne`, `AB_Lieutenant`) are in `decorate_ab.txt`, and DECORATE class names are always resolved at runtime with `(class<Actor>)(stringVar)`.
- Class-level `static const` arrays must be qualified (`AB.RegionCode[...]`) inside static functions.
- Field and method names collide case-insensitively (hit twice already).
- Rock textures (`JROCK1`, `CROCK1`, `HROCK1`) look cloudy rather than rocky. Cosmetic.
- `gen_art_sprites.py` palm trunk and a few sprites are rough. Cosmetic.

---

## 4. How to build and test

Build (needs Python 3 with numpy and Pillow):

```
python tools/build.py              # full build → AncientBounties.pk3
python tools/build.py --no-import  # skip re-importing the 40 MB of packs
python tools/build.py --no-zip     # leave build/ as a loose folder (UZDoom can -file a folder)
```

Reading `_modding` straight off the Windows mount is very slow (6,700 files). Copy it to local disk first and pass `--modding`.

Headless test rig (Linux, used during development; scripts in `_dev/headless/`):

- UZDoom 5.0.3 Linux AppImage extracted with `--appimage-extract`, run under `xvfb-run`.
- `chk.sh` — rebuild and load with `-norun`, grep for script errors. A startup error shows a dialog and hangs until the timeout, so errors take ~30 s to report.
- `shot.sh <secs> <out.png> args…` — run, grab the X root window, kill.
- **Use `+vid_rendermode 0`.** The hardware renderer draws a black 3D view under llvmpipe; the software renderer works.
- Do not `pkill -f uzdoom` from the same shell — it matches and kills itself.

The scripts hard-code paths under `$HOME/uz` and `$HOME/work/ab` from the original session and need adjusting.

---

## 5. Design reference

- **Rival:** Thorne Meridian, a PMC owned by Magnus Thorne. Races the player to each region's great treasure. Heat rises with each one the player takes.
- **Regions:** Peru, Egypt, Caribbean, Nepal, then the Meridian Citadel finale (unlocks once all four treasures are held by someone).
- **Expedition:** 4 stages — action, puzzle, random, vault (Citadel: 3). Pick one of three boons between stages, or extract early and bank the haul.
- **Camp:** Command Tent, Armory, Workshop, Infirmary, Storage, Radio Tower, levels 0–3. Resources: gold, supplies, materials, intel.
- **Crew:** Scout, Gunner, Scholar, Medic. One can be the player's partner (passive perk); the rest can be dispatched on off-screen runs.
- **Keys:** Q dodge roll, F medkit, B camp manager / field journal.
- **Map names:** `<region><A|P|V><n>`, e.g. `PEA1`, `EGP2`, `NEV1`; hub is `ABCAMP`.
- **Thing numbers:** 20000–20051, listed in `src/lumps/mapinfo.txt` and at the top of `gen_maps.py`.
