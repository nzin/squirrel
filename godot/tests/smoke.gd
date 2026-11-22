extends SceneTree
## Headless smoke test. Run from the repo root:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s tests/smoke.gd
## Drives Game.frame() directly (no real time) and asserts the pygame behaviour.

var failures := 0


func check(cond: bool, msg: String) -> void:
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        failures += 1


func _initialize() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    var dt := 1.0 / 60.0

    print("start state")
    check(game.squirrel.y == 460.0, "squirrel stands on the ground (y=460)")
    check(game.acorns == 3 and game.score == 0, "3 acorns, 0 points")
    check(game.clouds.size() > 6, "two cloud rows pre-filled (%d clouds)" % game.clouds.size())

    print("jump physics")
    game.do_jump()
    var min_y: float = game.squirrel.y
    var frames := 0
    while frames < 200:
        game.frame(dt)
        min_y = minf(min_y, game.squirrel.y)
        frames += 1
        if game.squirrel.y >= 460.0 and frames > 5:
            break
    var rise := 460.0 - min_y
    check(rise > 130.0 and rise < 145.0, "jump rises ~140px (got %.1f)" % rise)
    check(game.squirrel.y == 460.0, "lands back on the ground after %d frames" % frames)

    print("throwing")
    var before: int = game.acorns
    game.do_throw()
    check(game.acorns == before - 1 and game.shots.size() == 1, "throw costs one acorn")
    var skunk := Enemy.create("skunk", 400.0, 420.0)
    game.layers["ground"].add_child(skunk)
    game.enemies.append(skunk)
    for i in 40:
        game.frame(dt)
    check(skunk.defeated and game.score == 1, "acorn defeats a skunk (+1 point)")
    check(game.shots.is_empty(), "acorn is consumed on hit")

    print("two-hp enemy")
    var beaver := Enemy.create("beaver", 500.0, 460.0)
    game.layers["ground"].add_child(beaver)
    game.enemies.append(beaver)
    game.acorns = 5
    game.do_throw()
    for i in 30:
        game.frame(dt)
    check(not beaver.defeated and beaver.hp == 1, "beaver survives the first acorn")
    game.do_throw()
    for i in 30:
        game.frame(dt)
    check(beaver.defeated, "beaver falls after the second acorn")

    print("underground mole is harmless and unhittable")
    var mole := Enemy.create("mole", 600.0, 440.0)
    check(mole.underground and not mole.hittable(), "new mole starts underground")

    print("spawning + box collection")
    game.reset_game()
    var saw_box := false
    var saw_tree := false
    var saw_skunk := false
    for i in 1400:
        game.squirrel.game_over = false
        game.squirrel.reset()  # immortal run: just exercise the spawner
        game.frame(dt)
        saw_box = saw_box or not game.boxes.is_empty()
        saw_tree = saw_tree or not game.trees.is_empty()
        saw_skunk = saw_skunk or game.enemies.any(func(e): return e.kind == "skunk")
    check(saw_box and saw_tree and saw_skunk, "boxes, trees and skunks spawn over time")

    print("bump a box from below")
    game.reset_game()
    var box := Box.new()
    box.place(60.0, 330.0)  # right above the squirrel's jump path
    game.layers["boxes"].add_child(box)
    game.boxes.append(box)
    game.next_box = 1e9
    game.next_tree = 1e9
    game.next_skunk = 1e9
    game.next_bird = 1e9
    game.do_jump()
    for i in 40:
        game.frame(dt)
    check(box.collected, "jumping into a box collects it")
    check(game.acorns >= 4 and game.acorns <= 6, "box gave 1-3 acorns (acorns=%d)" % game.acorns)

    print("standing on a tree")
    game.reset_game()
    game.next_box = 1e9
    game.next_tree = 1e9
    game.next_skunk = 1e9
    game.next_bird = 1e9
    var t2 := TreeProp.new()
    t2.place(300.0, 425.0)
    game.layers["trees"].add_child(t2)
    game.trees.append(t2)
    # jump just before reaching the tree so we are above it when it arrives
    var landed := false
    var rode := 0
    var jumped := false
    for i in 600:
        if not jumped and t2.x - (game.squirrel.x + game.squirrel.w) < 70.0:
            game.do_jump()
            jumped = true
        game.frame(dt)
        if game.squirrel.game_over:
            break
        if jumped and absf((game.squirrel.y + game.squirrel.h) - t2.y) < 1.0 and game.squirrel.x < t2.x + t2.w and game.squirrel.x + game.squirrel.w > t2.x:
            landed = true
            rode += 1
    check(not game.squirrel.game_over, "jumping onto a tree does not kill")
    check(landed and rode > 10, "squirrel stays on top of the tree (%d frames)" % rode)
    check(game.squirrel.y == 460.0, "squirrel drops to the ground once the tree has passed")

    print("menu")
    check(Hud.menu_items().has("Quit"), "menu has a Quit entry")

    print("game over and menu")
    game.reset_game()
    var tree := TreeProp.new()
    tree.place(300.0, 425.0)
    game.layers["trees"].add_child(tree)
    game.trees.append(tree)
    game.next_box = 1e9
    game.next_tree = 1e9
    game.next_skunk = 1e9
    game.next_bird = 1e9
    var n := 0
    while not game.squirrel.game_over and n < 600:
        game.frame(dt)
        n += 1
    check(game.squirrel.game_over, "walking into a tree ends the game (frame %d)" % n)
    var scroll_at_death: float = game.scroll_offset
    for i in 30:
        game.frame(dt)
    check(game.scroll_offset == scroll_at_death, "world freezes on game over")
    check(not game.hud.overlay.visible and game.hud.banner.visible, "GAME OVER banner shown first")
    for i in 180:
        game.frame(dt)
    check(game.hud.overlay.visible, "menu appears after 3 s")
    game.reset_game()
    game.frame(dt)
    check(not game.squirrel.game_over and game.score == 0 and game.acorns == 3, "restart resets the run")

    print("")
    print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
    quit(1 if failures > 0 else 0)
