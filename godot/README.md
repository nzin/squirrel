# Squirrel (Godot 4 port)

1:1 port of `../squirrel/main.py` (pygame) to Godot 4. Same physics, spawn tables and rules; the pygame version is untouched until this one is confirmed at parity.

## Run

Open this folder in the Godot 4 editor and press F5, or:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

Controls: **Space** jump, **Shift** throw acorn. Game-over menu: Up/Down, Enter/Space, Esc.

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
- `scripts/{box,cloud,tree_prop,acorn,popup_acorn,rainbow_acorn,background,hud}.gd` - the rest
