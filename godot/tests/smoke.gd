extends SceneTree
## Headless smoke test. Run from the repo root:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s tests/smoke.gd
## Drives Game.frame() directly (no real time) and asserts the pygame behaviour.

var failures := 0


func check(cond: bool, msg: String) -> void:
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        failures += 1


## Clear the world and stop all spawning so a test fully controls what is on screen.
func _quiet(game: Node) -> void:
    game.reset_game()
    for key in ["next_box", "next_tree", "next_skunk", "next_beaver", "next_mole", "next_bird", "next_ptero"]:
        game.set(key, 1e9)


func _initialize() -> void:
    # never touch the real save file
    Profile.save_path = "user://smoke_test.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
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
    check(game.profile.coins >= 1, "box also gave a coin (coins=%d)" % game.profile.coins)

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

    print("standing on an opponent")
    game.reset_game()
    game.next_box = 1e9
    game.next_tree = 1e9
    game.next_skunk = 1e9
    game.next_bird = 1e9
    var sk := Enemy.create("skunk", 300.0, 380.0)
    game.layers["ground"].add_child(sk)
    game.enemies.append(sk)
    var on_skunk := 0
    var jumped2 := false
    for i in 600:
        if not jumped2 and sk.x - (game.squirrel.x + game.squirrel.w) < 70.0:
            game.do_jump()
            jumped2 = true
        game.frame(dt)
        if game.squirrel.game_over:
            break
        if jumped2 and absf((game.squirrel.y + game.squirrel.h) - sk.y) < 1.0 and game.squirrel.x < sk.x + sk.w and game.squirrel.x + game.squirrel.w > sk.x:
            on_skunk += 1
    check(not game.squirrel.game_over, "jumping onto an opponent does not kill")
    check(on_skunk > 10, "squirrel stays on top of the opponent (%d frames)" % on_skunk)
    check(game.squirrel.y == 460.0, "squirrel drops to the ground after the opponent has passed")

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


    print("economy: coins from kills")
    _quiet(game)
    game.profile.coins = 0
    var sk2 := Enemy.create("skunk", 400.0, 430.0)
    game.layers["ground"].add_child(sk2)
    game.enemies.append(sk2)
    game.do_throw()
    for i in 120:
        game.frame(dt)
        if sk2.defeated:
            break
    check(sk2.defeated and game.profile.coins == 1, "defeating a skunk pays 1 coin (coins=%d)" % game.profile.coins)

    print("weapons")
    _quiet(game)
    game.weapon = "spread"
    game.acorns = 5
    game.do_throw()
    check(game.shots.size() == 3 and game.acorns == 2, "triple acorn fires 3 shots for 3 ammo")
    game.reset_game()
    game.weapon = "pinecone"
    game.acorns = 1
    game.do_throw()
    check(game.shots.size() == 1 and game.shots[0].kind == "acorn" and game.acorns == 0, "too little ammo falls back to a plain acorn")
    game.acorns = 0
    game.do_throw()
    check(game.shots.size() == 1, "no ammo at all: nothing is thrown")

    # boomerang: out and back, never leaves the screen, removed on return
    game.reset_game()
    _quiet(game)
    game.weapon = "boomerang"
    game.acorns = 2
    game.do_throw()
    var boom: Shot = game.shots[0]
    var far := 0.0
    var ticks := 0
    while boom.active and ticks < 300:
        game.frame(dt)
        far = maxf(far, boom.x)
        ticks += 1
    check(far - 90.0 > 250.0 and not boom.active, "boomerang flies out %.0f px then returns and is removed" % (far - 90.0))
    # a piercing shot hits each enemy once per leg
    var beav := Enemy.create("beaver", 300.0, 420.0)
    game.layers["ground"].add_child(beav)
    game.enemies.append(beav)
    var b2 := Shot.create("boomerang", 300.0, 440.0)
    game._shot_hits_enemies(b2)
    game._shot_hits_enemies(b2)
    check(beav.hp == 1 and not beav.defeated, "boomerang hits once on the way out")
    b2.hit_ids.clear()  # what the return leg does
    game._shot_hits_enemies(b2)
    check(beav.defeated, "...and again on the way back")

    # pinecone bomb: area damage, spares far-away enemies
    game.reset_game()
    _quiet(game)
    var near1 := Enemy.create("skunk", 400.0, 380.0)
    var near2 := Enemy.create("skunk", 450.0, 380.0)
    var far1 := Enemy.create("skunk", 700.0, 380.0)
    for en in [near1, near2, far1]:
        game.layers["ground"].add_child(en)
        game.enemies.append(en)
    var bomb := Shot.create("pinecone", 410.0, 430.0)
    game._add_shot(bomb)
    bomb.detonate()
    game._update_shots()
    check(near1.defeated and near2.defeated and not far1.defeated, "pinecone blast hits nearby enemies only")

    # rainbow beam pierces everything in line and survives
    game.reset_game()
    _quiet(game)
    var r1 := Enemy.create("skunk", 400.0, 400.0)
    var r2 := Enemy.create("skunk", 440.0, 400.0)
    for en in [r1, r2]:
        game.layers["ground"].add_child(en)
        game.enemies.append(en)
    var beam := Shot.create("rainbow", 420.0, 440.0)
    game._shot_hits_enemies(beam)
    check(r1.defeated and r2.defeated and beam.active, "rainbow beam pierces and keeps going")

    # homing acorn curves up to an enemy that is not on its path
    game.reset_game()
    _quiet(game)
    var high := Enemy.create("bird", 500.0, 250.0)
    game.layers["air"].add_child(high)
    game.enemies.append(high)
    var hom := Shot.create("homing", 140.0, 470.0)
    for i in 200:
        hom.update(game.squirrel, game.enemies)
        game._shot_hits_enemies(hom)
        if not hom.active:
            break
    check(high.defeated, "homing acorn steers into an enemy above its path")

    # bouncing chestnut stays above the ground line
    var nut := Shot.create("chestnut", 140.0, 470.0)
    var lowest := 0.0
    for i in 200:
        nut.update(game.squirrel, [])
        lowest = maxf(lowest, nut.y + nut.h)
    check(lowest <= Cfg.SOIL_Y + 0.01, "chestnut bounces on the ground line")

    print("shop and persistence")
    game.reset_game()
    var pr: Profile = game.profile
    pr.coins = 40
    check(Shop.activate(pr, "spread").begins_with("Bought") and pr.coins == 25 and pr.equipped == "spread", "buy + auto-equip a weapon")
    check(Shop.activate(pr, "homing") == "Not enough coins." and pr.coins == 25 and not pr.owns("homing"), "too expensive: nothing changes")
    Shop.activate(pr, "acorn")
    check(pr.equipped == "acorn" and pr.coins == 25, "owned weapons equip for free")
    check(Shop.activate(pr, Shop.AMMO_ROW) == "Pouch upgraded!" and pr.coins == 15 and pr.ammo_level == 1, "buy +1 starting acorn")
    game.reset_game()
    check(game.acorns == 4, "next run starts with 4 acorns")
    game.cycle_weapon()
    check(game.weapon == "spread", "Q cycles through owned weapons")
    game.cycle_weapon()
    check(game.weapon == "acorn", "...and wraps around")
    var reloaded := Profile.new()
    reloaded.load_from_disk()
    check(reloaded.coins == 15 and reloaded.owned == pr.owned and reloaded.ammo_level == 1, "profile survives a reload")

    print("shop UI")
    game.reset_game()
    game.squirrel.game_over = true
    game.over_started = true
    game.over_elapsed = 4.0
    game.menu_state = "shop"
    game.frame(dt)
    check(game.hud.overlay.visible and game.hud.menu_root.get_child_count() > 15, "shop screen renders (%d nodes)" % game.hud.menu_root.get_child_count())
    var down := InputEventAction.new()
    down.action = "ui_down"
    down.pressed = true
    game._menu_input(down)
    check(game.shop_selection == 1, "Down moves the shop selection")
    game.reset_game()

    DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
    print("")
    print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
    quit(1 if failures > 0 else 0)
