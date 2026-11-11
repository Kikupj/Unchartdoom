# Tactical Duck & Dodge AI (`TacticalDuckDodge`)

An experimental **WinBack / Time Crisis** enemy combat behavior mod for **UZDoom / GZDoom** (`ZScript 4.10+`), built for testing with `DeePaybackEnemies` and designed for drop-in integration into **New Bricks City**.

---

## Features Overview

### 1. Pop-Up & Duck Cycle (`TSTATE_DUCK`, `TSTATE_POPUP`, `TSTATE_CROUCH_FIRE`)
- **Post-Burst Ducking**: Enemies crouch down after firing a burst—or after a capped burst duration on continuous-fire (`A_SentinelRefire` / `A_CPosRefire`) enemies—turning static turret-style monsters into rhythmic cover shooters.
- **50% Hitbox Compression & Stationary Lock**: While ducked, enemy collision height drops by 50% (`28` map units on a standard `56`-height human), their sprite compresses cleanly at their feet, and `A_Chase` is frozen so enemies remain 100% stationary with zero frame/angle jitter.
- **Pop-Out Telegraph**: Before opening fire from a crouch or corner peek, enemies spring up into a brief aiming stance with an optional muzzle glint (`TacticalTelegraphGlint`).
- **Crouched Firing**: Enemies in open ground occasionally fire bursts directly from a crouched stance (with projectile spawn height automatically lowered to match their crouched weapon).

### 2. Evasive Side-Step & 360° Combat Dive-Roll (`TSTATE_DODGE_STRAFE`, `TSTATE_DODGE_ROLL`)
- **Crosshair & Damage Reaction**: Enemies detect when the player's crosshair is aimed at them or when bullets impact nearby.
- **Two Evasion Styles**:
  - **Strafe Dash**: Athletic lateral burst with directional body lean.
  - **Combat Dive-Roll**: Full 360° sprite roll (`+ROLLSPRITE`, `+ROLLCENTER`) with halved hitbox height (`28` units).

### 3. 3D Geometry & Wall-Edge Cover Detection (`COVER_LOW`, `COVER_FULL`)
- **Two-Ray 3D Classification (`ClassifyCoverAt`)**: Traces two `TRF_THRUACTORS` rays from the player's eye position (`viewz`) to any candidate floor position:
  - **`COVER_NONE`**: Exposed at both crouched (`19u`) and standing (`44u`) heights.
  - **`COVER_LOW`**: Waist-high geometry (ledges, crates, windowsills, railings, stairs) blocks crouched height while standing height is clear. Enemies prioritize ducking in place behind the ledge and popping up to shoot over it.
  - **`COVER_FULL`**: Solid wall corners or pillars block both crouched and standing heights. Enemies prioritize rolling/dashing behind the corner edge.
- **WinBack-Style Corner Hide & Peek-Out (`TSTATE_CORNER_HIDE`, `TSTATE_CORNER_PEEK`)**: When an enemy rolls from an active firing lane behind a wall corner (`COVER_FULL`), they remember their firing edge, wait safely behind the wall, and then lean/step laterally back out until line-of-sight is restored to fire a burst.

### 4. Gunfire Suppression Retreat & Silent-Player Push (`TSTATE_RETREAT`, `TSTATE_PUSH`)
- **Tactical Retreat Under Fire**: Detects player hitscan `BulletPuff` impacts, projectiles, and active trigger pulls within a suppression cone. Enemies back away from gunfire at boosted speed (`nbc_retreat_speed`) and automatically snap into **Corner Hide** or **Low-Wall Duck** as soon as backing up puts geometry between them and the player.
- **Aggressive Push When Player is Out of View & Silent**: Tracks how long the player has been out of line-of-sight (`!CheckSight`) AND not firing (`!BT_ATTACK`). Once both exceed `nbc_push_delay_tics` (default `35` tics / `1.0s`), enemies break out of cover and aggressively advance on the player's position—immediately aborting the push to dodge/duck if the player pops out and opens fire.

### 5. Enemy Magazine Ammo & Tactical Reloads (`TSTATE_RELOAD`)
- **Automatic Weapon Magazine Sizing**: Counts enemy projectile shots via `WorldThingSpawned` and sizes magazine capacity by weapon type (`7–10` for pistols/revolvers, `5–7` for shotguns/heavy bursts, `5–8` for rifles/snipers, `16–22` for SMGs/assault rifles) or via manual CVar override (`nbc_reload_shots`).
- **Cover-First Reloading**: When an enemy runs out of ammo in the open, they attempt to dive/roll into nearby cover before reloading; enemies already in cover with `<25–33%` ammo top off proactively before peeking out.
- **3-Stage Audio & Visual Telegraph**: Ejects a bouncing spent magazine (`TacticalSpentMag`) and plays distinct mag-out (`weapons/sshoto`), mag-in (`weapons/sshotl`), and weapon-rack (`en/mgCOCK` / `en/shotpump`) sounds while crouched in a vulnerable reload state.

### 6. Shootable Cooking Explosive Barrels & Enemy Panic-Flee (`TSTATE_BARREL_FLEE`)
- **Cooking Barrels (`CookingExplosiveBarrel`)**: Lethal damage(<60 dmg) causes `ExplosiveBarrel` to hiss, vibrate, bulge, flash, and vent rising sparks for `nbc_barrel_cook_tics` (default `52` tics / `~1.5s`) before exploding. Shooting a cooking barrel again accelerates or immediately triggers detonation.
- **Random Enemy Detection & Panic Flee**: Enemies within `nbc_barrel_panic_radius` roll once per barrel against `nbc_barrel_flee_chance` (default `65%`). Enemies that notice the cooking barrel let out a startled voice bark, optionally dive-roll away if dangerously close (`<120u`), and sprint clear of the blast radius.

### 7. Ported KAI & Smart Marines Mechanics
- **3D Incoming Projectile Trajectory Dodging (`FindIncomingProjectileThreat` / `Distance3DLine`)**: Tracks active missiles and uses 3D point-to-line-segment math (`KAI_Math.distance3dline` / `SM_ShouldDodgeProjectile`) to detect rockets, plasma, or tracer projectiles flying toward an enemy (`nbc_proj_dodge_range`), dodging perpendicular (`±90°`) away from the projectile's passing side or ducking immediately if already behind waist-high cover.
- **Mid-Dodge Snap-Shot Attack (`TryFireMidDodgeSnapShot`)**: Ported from Smart Marines' `Jump.Dodge.Attack`, allowing enemies to fire an opportunistic snap-shot at the apex (~50%) of a strafe-dash or combat dive-roll (`nbc_dodge_attack`).
- **Visual Backward Walking During Retreat (`SpriteRotation = 180`)**: Ported from Smart Marines (`SM_Chase`), rotating the enemy's rendered sprite 180° while backing away (`bFRIGHTENED`) so retreating enemies visually face the player instead of turning their backs.
- **Solid Prop & Obstacle Cover (`nbc_prop_cover_enable`)**: Extends `IsRayFromTargetBlockedByGeometry` so solid non-monster map props (crates, barricades, tech pillars) count as valid waist-high or full cover alongside sector geometry.
- **Active Cover Pathing (`TSTATE_SEEK_COVER`)**: Ported from `SM_LocateNearbyCover`, scanning forward and laterally up to `256` map units when an enemy is caught in the open beyond single-roll range (`nbc_active_cover_run`) and sprinting directly to that cover spot before crouching/hiding.

---

## Quick Start

### Option A: Using the Packaged `.pk3`
```bat
uzdoom.exe -iwad "freedoom-0.13.0\freedoom2.wad" -file "DeePaybackEnemies" "TacticalDuckDodge.pk3" +map MAP01
```

### Option B: Using the Unpacked Folder (or `run_tactical_test.bat`)
Double-click `run_tactical_test.bat` in `_experiments`, or run:
```bat
uzdoom.exe -iwad "freedoom-0.13.0\freedoom2.wad" -file "DeePaybackEnemies" "TacticalDuckDodge" +map MAP01
```

---

## In-Game Menu & Console CVars

All settings can be adjusted live under **Options -> Tactical Duck & Dodge AI (Experiment)** or via the console (`35 tics = 1.0 second`):

| CVar | Default | Description |
| :--- | :---: | :--- |
| `nbc_tactical_enable` | `true` | Master toggle for all Tactical AI behaviors |
| `nbc_duck_chance` | `75` | % chance to duck after firing or when aimed at |
| `nbc_dodge_chance` | `65` | % chance to side-step or roll when aimed at / damaged |
| `nbc_roll_enable` | `true` | Allow 360° combat dive-rolls in addition to strafe-dashes |
| `nbc_crouch_fire` | `true` | Allow enemies to occasionally fire from a crouched stance |
| `nbc_telegraph_flash` | `true` | Spawn subtle muzzle glint when popping out of cover |
| `nbc_proj_dodge_enable` | `true` | Dodge incoming projectiles using 3D trajectory math (KAI/SM port) |
| `nbc_proj_dodge_range` | `384` | Detection range (map units) for incoming projectiles |
| `nbc_dodge_attack` | `true` | Allow enemies to fire a snap-shot mid-dodge (Smart Marines port) |
| `nbc_active_cover_run` | `true` | Sprint to distant cover (up to `256u`) when in the open |
| `nbc_prop_cover_enable` | `true` | Treat solid non-monster props/obstacles as valid cover |
| `nbc_reload_enable` | `true` | Enable per-enemy magazine tracking and crouched reloads |
| `nbc_reload_tics` | `52` | Reload duration in tics (`~1.5s`) |
| `nbc_reload_shots` | `0` | `0` = Auto mag size by weapon type; `>0` = fixed shot count |
| `nbc_barrel_cook_enable` | `true` | Barrels cook/sizzle before exploding |
| `nbc_barrel_cook_tics` | `52` | Barrel cooking duration in tics (`~1.5s`) |
| `nbc_barrel_flee_chance` | `65` | % chance an enemy notices a cooking barrel and flees |
| `nbc_barrel_panic_radius`| `240` | Detection/flee radius (map units) around a cooking barrel |
| `nbc_barrel_flee_speed` | `1.55` | Sprint speed multiplier when fleeing a cooking barrel |
| `nbc_cover_seek` | `true` | Scan 3D geometry for wall corners and low ledges |
| `nbc_corner_peek` | `true` | Enable *WinBack*-style corner hiding and peeking out |
| `nbc_open_duck` | `true` | Allow ducking in open ground when no low cover is nearby |
| `nbc_cover_search_dist` | `128` | Max distance (map units) to scan for cover edges |
| `nbc_retreat_enable` | `true` | Retreat toward cover when suppressed by player gunfire |
| `nbc_retreat_chance` | `55` | % chance to retreat when under suppressive gunfire |
| `nbc_retreat_speed` | `1.35` | Speed multiplier while retreating |
| `nbc_retreat_tics` | `45` | Retreat duration in tics |
| `nbc_push_enable` | `true` | Push aggressively when player is out of view and silent |
| `nbc_push_delay_tics` | `35` | Tics player must be hidden & silent before push (`1.0s`) |
| `nbc_push_speed` | `1.45` | Speed multiplier while pushing |
| `nbc_push_tics` | `85` | Max push duration in tics |
| `nbc_roll_speed` | `6.0` | Roll lateral velocity (map units/tic) |
| `nbc_roll_tics` | `24` | Roll 360° spin duration in tics |
| `nbc_strafe_speed` | `6.5` | Strafe dash lateral velocity (map units/tic) |
| `nbc_strafe_tics` | `18` | Strafe dash duration in tics |
| `nbc_duck_tics` | `40` | Base duck / cover wait duration in tics (`±25%` random) |
| `nbc_debug_tactical` | `false` | Print state transitions & measured distances to console |

---

## Porting to *New Bricks City*

Because `TacticalDuckDodge` uses a non-destructive `EventHandler` (`TacticalAIEventHandler`) and attaches an `Inventory` controller (`TacticalAIController`) at runtime:
1. Copy `ZSCRIPT.zs`, `CVARINFO.txt`, and `MENUDEF.txt` into the main project (or load `TacticalDuckDodge.pk3`).
2. Add `"TacticalAIEventHandler"` to `AddEventHandlers` in `MAPINFO`'s `GameInfo` block.
3. Customize `TacticalAIEventHandler::IsEligibleMonster()` or `TacticalAIController::NotifyWeaponFired()` if custom enemy classes or projectile types are added.

