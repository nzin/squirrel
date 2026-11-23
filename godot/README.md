# Squirrel (Godot 4 port)

Godot 4 version of the squirrel game (originally ported 1:1 from a pygame prototype, since removed; it remains in git history).

## Run

Open this folder in the Godot 4 editor and press F5, or:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

Controls: **Space** jump, **Shift** throw the equipped weapon, **Q** switch weapon, **Esc** pause menu (continue / restart / language / controls / quit). Menus: Up/Down, Enter, Left/Right changes the language.

## Game flow

A *game* is a series of **runs**:

1. A run lasts **60 seconds** (progress line along the bottom, timer at the top). Every run is harder: faster scrolling, closer spawns, and new opponents (beavers from run 2, moles from run 3).
2. **Every 3rd run ends with a boss** (giant beaver, a cleaver-wielding boar, giant skunk, then a tougher cycle; the boar uses local-only licensed art, see `CREDITS.md` - without it a giant croco takes its place). You get extra acorns, the boss charges after a red blink telegraph, and the run ends when it is defeated.
3. A finished run pays a completion bonus, then the screen **fades** to the **shop**; choosing *Start run N* fades into the next run.
4. You have **3 lives** (small squirrels under the score, max 6). A hit costs one; you get back up after a moment, blinking and invulnerable, with the obstacle that killed you cleared away. Losing the last life ends the game; *Restart* begins a new one. **Coins, weapons and upgrades reset every game**; only the best score, best run and the language are saved (`user://squirrel.cfg`).

## Economy and weapons

- **Acorns** are ammo, spent per throw (each weapon has an ammo cost). Boxes and rainbow acorns refill them; each run starts with 3 acorns (+1 per *Bigger Pouch* level).
- **Coins** (gold coin counter, top right): skunk/bird 3, beaver/mole 5, croco 6, pterodactyl 8, bosses 40-80; `?` boxes 2, rainbow acorns 5, smashed trees 2, plus the run bonus.
- **Lives** are earned by defeating a boss (+1), by finding the rare **1UP heart** on the top cloud row (+1, or 10 coins at the maximum), or in the shop (*Extra Life*, 60 coins). Maximum 6.
- **Shop** (between runs, kept by a dwarf who describes each ware in a speech bubble and cheers when you buy): buy weapons (equipped on purchase), *Matrix Fist* (pack of 3), *Extra Life* and the *Bigger Pouch* upgrade (5 levels).
- Weapons (see `scripts/weapons.gd`): Acorn, Triple Acorn, Boomerang, Bouncing Chestnut, Pinecone Bomb, Rainbow Beam, Homing Acorn. Not enough ammo for the equipped weapon falls back to a plain acorn.
- You can stand on trees and on opponents; collision boxes follow the visible part of each sprite (`hitbox` fractions in `enemy.gd` / `tree_prop.gd`, measured from the art).

### Matrix Fist (key F)

Bought in the shop as a **pack of 3 charges** (45 coins; a fist + the count appears in the HUD). Pressing **F** starts a 4-second sequence and **the attack starts at second 0**: the squirrel dashes **across the whole screen** (0-1.5 s, ghost trail, invulnerable) and back (1.5-3 s). Meanwhile the world slows to 10 % and the light dims (0-1 s), stays slow, and speeds up with the light returning (3-4 s).

It does not stop at the first thing it meets: **every enemy and tree on the way is hit, once on the way out and once on the way back** - 3 damage per hit (shields don't help), trees are smashed, enemy projectiles destroyed. It flies level with the nearest target ahead (ground, or a flyer's height), never above it. Implemented with `Cfg.time_scale`, which every moving thing multiplies its per-tick movement by, so the slow-motion is smooth.

## Smarter enemies

Data-driven in `scripts/enemy.gd` (`ai`, `shoot`, `shoot_from`, `shield_from` in `KINDS`); each run adds `scale_for_run` armor and speed.

| Enemy | Movement | From run | Shoots (from run) |
|---|---|---|---|
| Skunk | walks | 1 | gas cloud rolling on the ground (3) |
| Bird | sine wave | 1 | drops eggs (4) |
| Pterodactyl | blinks, then **dives** at you | 1 (on clouds) | fireballs (5) |
| Beaver | blinks, then **charges** | 2 | - |
| Mole | **tunnels toward you**, surfaces just ahead | 3 | - |
| Croco | **leaps** | 4 | - |
| Hedgehog | tucks in and **rolls as a spiky ball** (acorns bounce off) | 5 | - |
| Owl | slow wide **swoops** | 7 | - |
| Bee | fast **zigzag**, in swarms of 3 | 8 | - |
| Fox | runs fast, crouches, **pounces** | 9 | - |

Beaver, croco, fox and owl can carry a **frontal shield** - protected enemies only appear **from run 7**.

- **Shield** (run 7+): blocks acorns from the front; get it with the Rainbow Beam, a Pinecone blast, a boomerang on its way back, or the Matrix Fist.
- **Armor and enrage**: +1 hp every 3 runs, hit flash, small health bar; below half hp an enemy is faster and red-tinted (**enraged enemies only appear from run 4**, protected ones from run 7).
- Projectiles kill on any contact; shoot them down with any weapon. Bosses spit fireballs while they stand.
- Nobody shoots before run 3.

## Sound

The music is an original **arcade fighting-game soundtrack** (FM slap bass, FM piano and brass, a gritty saw lead, distorted power chords, gated-reverb drums, in a tense minor key), synthesized by `tools/make_arcade_music.py`. The effects are synthesized by `tools/make_sounds.py`, except 17 (impacts, coins, bell, interface clicks) from Kenney's CC0 packs, see `CREDITS.md`. Both run with `make sounds`; the files live in `godot/assets/audio/` (about 2 MB once compressed in the game). `scripts/audio_hub.gd` plays them:

- **Music** follows the situation and crossfades: a first theme (runs 1-2, 144 BPM), the same theme with more layers (3-5) and a faster, double-kick version (6+, 158 BPM), a dark boss track (160 BPM) with tom-roll fills, a funky "bonus stage" groove for the dwarf's shop, a KO fanfare for bosses, a round-win fanfare, and a tense "continue?" sting at game over.
- **Matrix Fist**: while time slows the music drops in pitch and is muffled, then winds back up.
- **Effects**: every weapon has its own throw sound; hits, shields, coins, boxes, enemy warnings (charge, dive, pounce, shots), the dwarf's mumbling voice, menus and the fist's whoom, dash, thud and rewind.
- **Volumes**: *Music* and *Effects* in the pause and game-over menus (LEFT/RIGHT, or ENTER to cycle); saved with your profile.
- **Replacing a sound**: drop a `.wav` or `.ogg` with the same name into `assets/audio/sfx/` or `music/` (names are in `audio_hub.gd` and the `tools/make_sounds.py` tables). Missing files are skipped silently. Note: browsers only start audio after the first key press.

## Art

The four newest opponents (hedgehog, fox, owl, bee) and the dwarf shopkeeper are original artwork drawn by `tools/make_sprites.py` (`make sprites`). See [`../CREDITS.md`](../CREDITS.md) for sources, licences, what is still undocumented, and how to add characters.

## Languages

English and French (`scripts/lang.gd`). The first launch follows the OS language; change it any time in the pause or game-over menu. To add a language, add it to `Lang.LANGUAGES` / `NATIVE_NAMES` and a translation table next to `FR`.

## Build (from the repo root, see `Makefile`)

```bash
make templates   # one-time: download Godot export templates (~1.3 GB)
make web         # -> godot/build/web/   (then: make serve)
make macos       # -> godot/build/macos/Squirrel.app (universal, runs full screen; make run-macos)
```

## Test (headless)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import   # first time only
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s tests/smoke.gd
```

## Layout

- `scripts/game.gd` - main loop, spawner, collisions, game-over flow (mirrors the pygame loop order)
- `scripts/squirrel.gd` - player physics (solid boxes, one-way clouds)
- `scripts/enemy.gd` - every enemy is one data-driven class; add a type by adding an entry to `KINDS`
- `scripts/cfg.gd` - tuning constants
- `scripts/weapons.gd` (catalogue) / `shot.gd` (projectiles) / `loadout.gd` (coins, weapons: one game) / `profile.gd` (saved: best score, language) / `shop.gd` / `lang.gd` (translations)
- `scripts/enemy_shot.gd` (enemy projectiles) / `ghost.gd`, `punch_fx.gd`, `fist_icon.gd`, `coin_icon.gd` (effects, icons)
- `scripts/{box,cloud,tree_prop,popup_acorn,rainbow_acorn,background,hud}.gd` - the rest
