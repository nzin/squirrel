# Squirrel

A side-scrolling game starring a squirrel, built with Godot 4. The project lives in [`godot/`](godot/README.md).

![Squirrel gameplay: run 8 - an exploding chestnut blows up two skunks while a swarm of bees flies overhead, with a hedgehog, a fox, a tree and a 1UP heart on the way; the HUD shows lives, coins, the weapon with its chestnut count and the Matrix Fist charges](docs/screenshot.png)

```bash
make run     # play from source (windowed)
make web     # export the HTML5 build   -> godot/build/web/  (then: make serve)
make macos   # export the macOS app     -> godot/build/macos/Squirrel.app (full screen)
make test    # headless smoke test
```

See `make help` for all targets and [`godot/README.md`](godot/README.md) for controls and layout.

## Credits

- Game design, code and the original opponents (hedgehog, fox, owl, bee) and dwarf shopkeeper: see [`CREDITS.md`](CREDITS.md).
- The explorer shopkeeper and the boar boss that appear in some local builds are characters by **Robert Brooks / [Game Developer Studio](https://www.gamedeveloperstudio.com)** - thank you! See also his YouTube channel, [@gamedeveloperstudio](https://www.youtube.com/@gamedeveloperstudio/videos), which showcases his 2D game assets. Those files are licensed (not redistributable), so they are not part of this repository: buy them from the store to use them.
