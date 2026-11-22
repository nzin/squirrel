# Art credits and sourcing

Keep this file up to date: every image in `godot/assets/` must have a line here
with where it came from and under what licence it may be used.

## Original artwork (ours - no licence issue)

Drawn in code by [`tools/make_sprites.py`](tools/make_sprites.py) (`make sprites`):

| Files | What |
|---|---|
| `hedgehog1/2.png`, `hedgehog_ball.png` | hedgehog (walking, curled up) |
| `fox1/2.png` | fox |
| `owl1/2.png` | owl |
| `bee1/2.png` | bee |

Edit the script and re-run it to change these; `tools/sprite_hitbox.py` prints
the matching collision box (see below).

## Inherited artwork - origin not recorded

These came with the original prototype and **their origin and licence were not
documented**: `squirrel.png`, `skunk_*`, `beaver*`, `croco*`, `mole*`, `bird_*`,
`ptero*`, `tree*`, `cloud*`, `rainbow_acorn.png`, `background*.jpg`.
Before any public release, find where each came from (or replace it) and
record it here. `misc/` holds the source files of some of them.

## Getting more characters

- **Not used: screenshots of other people's games or videos** (for example the
  characters on the @gamedeveloperstudio YouTube channel). That is copyrighted art
  unless the creator licenses it, and their terms were not verified. If you get
  explicit written permission (or find the characters in a pack they sell or give
  away with a licence), add them like any other asset and record the licence above.
- **Safe sources**: [Kenney](https://kenney.nl/assets) (CC0), CC0 packs on
  [OpenGameArt](https://opengameart.org) (check each item's licence; CC-BY needs
  attribution here), free-licence packs on itch.io, or your own drawings
  (GIMP, or `tools/make_sprites.py`).

## Adding an enemy from a new sprite

1. Put the PNG frames in `godot/assets/` (characters face **left**, transparent
   background, same aspect ratio as the in-game size so nothing is distorted).
2. Run `python3 tools/sprite_hitbox.py frame1 frame2 ...` - it ignores transparent
   margins and thin tails and prints `"hit": Rect2(...)` for the collision box.
3. Add an entry to `Enemy.KINDS` in `godot/scripts/enemy.gd` (size, hp, coins,
   frames, `ai`, optional `shoot`), and a spawn rule in `godot/scripts/game.gd`.
4. Add a row to the credits table above.
