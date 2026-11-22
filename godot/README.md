# Squirrel (Godot 4 port)

Godot 4 version of the squirrel game (originally ported 1:1 from a pygame prototype, since removed; it remains in git history).

## Run

Open this folder in the Godot 4 editor and press F5, or:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

Controls: **Space** jump, **Shift** throw the equipped weapon, **Q** switch weapon. Game-over menu: Up/Down, Enter/Space, Esc.

## Economy and weapons

- **Acorns** are ammo, spent per throw (each weapon has an ammo cost). Boxes and rainbow acorns refill them.
- **Coins** are the shop currency and persist between runs (`user://squirrel.cfg`). Earned from defeated enemies (1-3 each), `?` boxes (+1) and rainbow acorns (+3).
- **Shop**: game-over menu -> *Shop*. Buy weapons (equipped on purchase) and the *Bigger Pouch* upgrade (+1 starting acorn per level, 5 levels).
- Weapons (see `scripts/weapons.gd`): Acorn, Triple Acorn, Boomerang, Bouncing Chestnut, Pinecone Bomb, Rainbow Beam, Homing Acorn. Not enough ammo for the equipped weapon falls back to a plain acorn.

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
- `scripts/weapons.gd` (catalogue) / `shot.gd` (projectile behaviour) / `profile.gd` (saved progress) / `shop.gd` (shop logic)
- `scripts/{box,cloud,tree_prop,popup_acorn,rainbow_acorn,background,hud}.gd` - the rest
