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
| `dwarf_idle/talk/happy.png` | the dwarf shopkeeper (three expressions) |

Edit the script and re-run it to change these; `tools/sprite_hitbox.py` prints
the matching collision box (see below).

## Inherited artwork - origin not recorded

These came with the original prototype and **their origin and licence were not
documented**: `squirrel.png`, `skunk_*`, `beaver*`, `croco*`, `mole*`, `bird_*`,
`ptero*`, `tree*`, `cloud*`, `rainbow_acorn.png`, `background*.jpg`.
Before any public release, find where each came from (or replace it) and
record it here. `misc/` holds the source files of some of them.

## Local-only licensed art (NOT in the repository)

`godot/private/` is git-ignored. Whatever lives there is optional: the game
uses it when present and falls back to built-in art when not, so the repo works
without it.

| Local file | Replaces | Fallback |
|---|---|---|
| `private/shopkeeper.png` | the shop owner | the original dwarf |
| `private/boar_1..3.png` | the second boss (run 6, 12, ...) with a cleaver-wielding boar, 3 frames for a pseudo animation | a giant croco |

The shopkeeper is the *Explorer character animated game sprite* from
[gamedeveloperstudio.com](https://www.gamedeveloperstudio.com/graphics/viewgraphic.php?page-name=Explorer-character-animated-game-sprite&item=1r6w4q805l5b592i6s)
(artist Robert Brooks, standard licence, $11.95); the boar boss is another
gamedeveloperstudio.com character (the "boar enemy" pack - find it in the store and
record its exact name here). Both were cut out of **screenshots**,
not downloaded from the store, so they are low resolution (faint grid lines from the
screenshot background remain) and **you do not hold a licence for them until you
buy the packs**. Buy them and replace the files with the
store's HD PNG frames before sharing or distributing any build. Never commit them, and
don't commit screenshots showing them (`docs/shop.png` and `docs/local-*.png` are
ignored for that reason).

## Getting more characters

- **Not used: screenshots of other people's games or videos.** The
  @gamedeveloperstudio YouTube channel promotes the **paid asset store**
  [gamedeveloperstudio.com](https://www.gamedeveloperstudio.com) (a few packs are
  free). Its [licence](https://www.gamedeveloperstudio.com/license.php) (checked
  Nov 2026) lets you use assets *downloaded from the store, free or bought* in
  commercial games, modified, without attribution - but **forbids redistributing
  the asset files themselves**. So:
  - frames grabbed from the videos are not licensed assets - don't use them;
  - if you buy or download a pack (e.g. the *Dwarves Character Pack*), keep the
    raw PNGs **out of this public repository** (gitignore them, or use a private
    repo) and record the purchase here; shipping them inside the built game is fine;
  - read the licence again before relying on this summary.
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
