# Squirrel

A side-scrolling game starring a squirrel, built with Godot 4. The project lives in [`godot/`](godot/README.md).

![Squirrel gameplay: run 9 - the squirrel throws a boomerang and an exploding chestnut (D key) past a tree, toward a mole, a skunk, a crocodile and a beaver, with a 1UP heart above; the HUD shows lives, coins, the weapon, the Matrix Fist charges (F) and the chestnut stock (D)](docs/screenshot.png)

```bash
make run     # play from source (windowed)
make web     # export the HTML5 build   -> godot/build/web/  (then: make serve)
make macos   # export the macOS app     -> godot/build/macos/Squirrel.app (full screen)
make test    # headless smoke test
```

See `make help` for all targets and [`godot/README.md`](godot/README.md) for controls and layout.

## Credits

- Game design and code; art credits and licences: see [`CREDITS.md`](CREDITS.md).
- The explorer shopkeeper and the boar boss that appear in some local builds are characters by **Robert Brooks / [Game Developer Studio](https://www.gamedeveloperstudio.com)** - thank you! See also his YouTube channel, [@gamedeveloperstudio](https://www.youtube.com/@gamedeveloperstudio/videos), which showcases his 2D game assets. Those files are licensed (not redistributable), so they are not part of this repository: buy them from the store to use them.
