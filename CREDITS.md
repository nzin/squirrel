# Art credits and sourcing

Keep this file up to date: every image in `godot/assets/` must have a line here
with where it came from and under what licence it may be used.

## Sound

**The music and fanfares are ours**: an arcade fighting-game soundtrack synthesized from scratch by
[`tools/make_arcade_music.py`](tools/make_arcade_music.py) (pure Python): no licence issue.
**Most effects are ours too**, synthesized by [`tools/make_sounds.py`](tools/make_sounds.py).
`make sounds` regenerates both.

**17 effects are from [Kenney](https://kenney.nl)** (Creative Commons Zero, CC0 - no
attribution required, but thank you!). They are `.ogg` files in `godot/assets/audio/sfx/`
that take priority over the synthesized `.wav` of the same name:

| Game sound | Kenney pack | Original file |
|---|---|---|
| `hit` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | `impactPunch_medium_001` |
| `fist_hit` | Impact Sounds | `impactPunch_heavy_001` |
| `shield_clang` | Impact Sounds | `impactMetal_heavy_001` |
| `box_bump` | Impact Sounds | `impactWood_medium_001` |
| `land` | Impact Sounds | `impactSoft_medium_001` |
| `splat` | Impact Sounds | `impactSoft_heavy_001` |
| `smash` | Impact Sounds | `impactPlank_medium_001` |
| `stomp` | Impact Sounds | `impactWood_heavy_000` |
| `mole_pop` | Impact Sounds | `impactMining_001` |
| `shop_bell` | Impact Sounds | `impactBell_heavy_000` |
| `coin` | [RPG Audio](https://kenney.nl/assets/rpg-audio) | `handleCoins2` |
| `buy` | RPG Audio | `handleCoins` |
| `ui_move` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | `tick_001` |
| `ui_select` | Interface Sounds | `confirmation_001` |
| `ui_back` | Interface Sounds | `close_001` |
| `pause` | Interface Sounds | `open_001` |
| `no_money` | Interface Sounds | `error_001` |

To swap any other sound for a better file, drop a file with the same name into the
folder and add a row here. CC0 / CC-BY music would be fine too (CC-BY needs attribution).

## Original artwork

None any more: the only sprites drawn by us (the owl, an earlier hedgehog, fox, bee and dwarf) were
replaced. The characters are either inherited prototype art (next section) or licensed
art kept out of the repository (see "Local-only licensed art").

## Inherited artwork - origin not recorded

These came with the original prototype and **their origin and licence were not
documented**: `squirrel.png`, `skunk_*`, `beaver*`, `croco*`, `mole*`, `bird_*`,
`ptero*`, `tree*`, `cloud*`, `rainbow_acorn.png`, `background*.jpg`.
Before any public release, find where each came from (or replace it) and
record it here. `misc/` holds the source files of some of them.

## Thanks

Some characters used in local builds are by **Robert Brooks, [Game Developer
Studio](https://www.gamedeveloperstudio.com)** - hand-drawn 2D game assets
sold (and sometimes given away) on his store and showcased on his YouTube channel
[@gamedeveloperstudio](https://www.youtube.com/@gamedeveloperstudio/videos).
Please support his work by buying the packs rather than copying them.

## Local-only licensed art (NOT in the repository)

`godot/private/` is git-ignored. Whatever lives there is optional: the game
uses it when present and falls back to built-in art when not, so the repo works
without it.

| Local file | Replaces | Fallback |
|---|---|---|
| `private/shopkeeper.png` (or `assets/shopkeeper.png`, found first) | the shop owner | no figure: the ware descriptions appear in a plain note panel |
| `private/explosion_1..9.png` | the Exploding Chestnut's explosion animation (9 frames, an orange cartoon blast with a shockwave ring and debris) | the plain orange burst |
| `private/mushroom_1..10.png` | the Pinecone Bomb's explosion when it hits something in the air (a rising mushroom cloud, 10 frames); also the chestnut's fallback | a plain white ring |
| `private/groundburst_1..9.png` | the Pinecone Bomb's explosion when it lands (a burst spreading along the ground, 9 frames) | the mushroom cloud, else the ring |
| `private/owl_1..3.png` | the owl (run 7+): eyes open, a blink and a sleepy look, shown as a blinking, drowsy owl; it swoops in slow wide waves | **none: no owls spawn** |
| `private/bee_1..4.png` | the bee swarm (run 8+): a cartoon bumblebee, 4 flapping frames | **none: no bees spawn** |
| `private/raccoon_1..9.png` | the raccoon (run 9+): 4 prowling frames, plus sitting up, holding a pot, raising it to throw, and eating; it throws nuts at the squirrel | **none: no raccoons spawn** |
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
  (GIMP).

## Adding an enemy from a new sprite

1. Put the PNG frames in `godot/assets/` (characters face **left**, transparent
   background, same aspect ratio as the in-game size so nothing is distorted).
2. Run `python3 tools/sprite_hitbox.py frame1 frame2 ...` - it ignores transparent
   margins and thin tails and prints `"hit": Rect2(...)` for the collision box.
3. Add an entry to `Enemy.KINDS` in `godot/scripts/enemy.gd` (size, hp, coins,
   frames, `ai`, optional `shoot`), and a spawn rule in `godot/scripts/game.gd`.
4. Add a row to the credits table above.
