extends SceneTree
## Headless smoke test. Run from the repo root:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s tests/smoke.gd
## Drives Game.frame() directly (no real time) and asserts the pygame behaviour.

var failures := 0
var _shield_leak := false


func check(cond: bool, msg: String) -> void:
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        failures += 1


func check_no_shield_run2(e: Enemy) -> void:
    if e.shielded:
        _shield_leak = true


## Clear the world and stop all spawning so a test fully controls what is on screen.
func _quiet(game: Node) -> void:
    game.start_run()
    for key in ["next_box", "next_tree", "next_skunk", "next_beaver", "next_mole", "next_bird", "next_ptero", "next_croco", "next_life", "next_bee", "next_hedgehog", "next_fox", "next_owl"]:
        game.set(key, 1e9)


func _initialize() -> void:
    # never touch the real save file
    Profile.save_path = "user://smoke_test.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
    var scene: PackedScene = load("res://scenes/main.tscn")
    var game := scene.instantiate()
    root.add_child(game)
    await process_frame
    Lang.current = "en"  # the tests read English text whatever the OS language is
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
    game.new_game()
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
    game.new_game()
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
    check(game.loadout.coins >= 1, "box also gave a coin (coins=%d)" % game.loadout.coins)

    print("standing on a tree")
    game.new_game()
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
        if not jumped and t2.rect().position.x - (game.squirrel.x + game.squirrel.w) < 70.0:
            game.do_jump()
            jumped = true
        game.frame(dt)
        if game.squirrel.game_over:
            break
        var tr: Rect2 = t2.rect()
        if jumped and absf((game.squirrel.y + game.squirrel.h) - tr.position.y) < 1.0 and game.squirrel.x < tr.end.x and game.squirrel.x + game.squirrel.w > tr.position.x:
            landed = true
            rode += 1
    check(not game.squirrel.game_over, "jumping onto a tree does not kill")
    check(landed and rode > 10, "squirrel stays on top of the tree (%d frames)" % rode)
    check(game.squirrel.y == 460.0, "squirrel drops to the ground once the tree has passed")

    print("standing on an opponent")
    game.new_game()
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
        if not jumped2 and sk.rect().position.x - (game.squirrel.x + game.squirrel.w) < 70.0:
            game.do_jump()
            jumped2 = true
        game.frame(dt)
        if game.squirrel.game_over:
            break
        var kr: Rect2 = sk.rect()
        if jumped2 and absf((game.squirrel.y + game.squirrel.h) - kr.position.y) < 1.0 and game.squirrel.x < kr.end.x and game.squirrel.x + game.squirrel.w > kr.position.x:
            on_skunk += 1
    check(not game.squirrel.game_over, "jumping onto an opponent does not kill")
    check(on_skunk > 10, "squirrel stays on top of the opponent (%d frames)" % on_skunk)
    check(game.squirrel.y == 460.0, "squirrel drops to the ground after the opponent has passed")

    print("menu")
    var ids: Array = game.menu_items().map(func(i: Dictionary) -> String: return i["id"])
    check(ids.has("quit") and ids.has("restart") and ids.has("language"), "game-over menu: restart, language, controls, quit")

    print("game over and menu")
    game.new_game()
    game.loadout.lives = 1  # the last life: dying ends the game
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
    game.new_game()
    game.frame(dt)
    check(not game.squirrel.game_over and game.score == 0 and game.acorns == 3, "restart resets the run")


    print("economy: coins from kills")
    _quiet(game)
    game.loadout.coins = 0
    var sk2 := Enemy.create("skunk", 400.0, 430.0)
    game.layers["ground"].add_child(sk2)
    game.enemies.append(sk2)
    game.do_throw()
    for i in 120:
        game.frame(dt)
        if sk2.defeated:
            break
    check(sk2.defeated and game.loadout.coins == Enemy.KINDS["skunk"]["coins"] and game.loadout.coins >= 3, "defeating a skunk pays %d coins" % game.loadout.coins)

    print("weapons")
    _quiet(game)
    game.weapon = "spread"
    game.acorns = 5
    game.do_throw()
    check(game.shots.size() == 3 and game.acorns == 2, "triple acorn fires 3 shots for 3 ammo")
    game.new_game()
    game.weapon = "pinecone"
    game.acorns = 1
    game.do_throw()
    check(game.shots.size() == 1 and game.shots[0].kind == "acorn" and game.acorns == 0, "too little ammo falls back to a plain acorn")
    game.acorns = 0
    game.do_throw()
    check(game.shots.size() == 1, "no ammo at all: nothing is thrown")

    # boomerang: out and back, never leaves the screen, removed on return
    game.new_game()
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
    game.new_game()
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
    game.new_game()
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
    game.new_game()
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

    print("hitboxes ignore empty sprite area")
    var sk3 := Enemy.create("skunk", 0.0, 0.0)
    check(sk3.rect().size.y < 45.0 and absf(sk3.rect().end.y - 80.0) < 0.5, "skunk hitbox is ~38 px tall, feet still on the ground (%.0f px)" % sk3.rect().size.y)
    for kind in ["beaver", "croco", "mole", "bird", "ptero"]:
        var en := Enemy.create(kind, 0.0, 0.0)
        check(en.rect().size.y < en.h and en.rect().size.x < en.w, "%s hitbox is tighter than its sprite" % kind)

    print("shop")
    game.new_game()
    var pr: Loadout = game.loadout
    check(pr.coins == 0 and pr.owned == ["acorn"] and pr.ammo_level == 0, "a new game starts with no coins, weapons or upgrades")
    pr.coins = 40
    check(Shop.activate(pr, "spread").begins_with("Bought") and pr.coins == 25 and pr.equipped == "spread", "buy + auto-equip a weapon")
    check(Shop.activate(pr, "homing") == "Not enough coins." and pr.coins == 25 and not pr.owns("homing"), "too expensive: nothing changes")
    Shop.activate(pr, "acorn")
    check(pr.equipped == "acorn" and pr.coins == 25, "owned weapons equip for free")
    check(Shop.activate(pr, Shop.AMMO_ROW) == "Pouch upgraded!" and pr.coins == 15 and pr.ammo_level == 1, "buy +1 starting acorn")
    game.start_run()
    check(game.acorns == 4 and game.loadout.coins == 15, "next run keeps purchases and starts with 4 acorns")
    game.cycle_weapon()
    check(game.weapon == "spread", "Q cycles through owned weapons")
    game.cycle_weapon()
    check(game.weapon == "acorn", "...and wraps around")
    game.new_game()
    check(game.loadout.coins == 0 and not game.loadout.owns("spread") and game.acorns == 3, "restarting wipes coins, weapons and upgrades")

    print("run lifecycle")
    game.new_game()
    _quiet(game)
    check(game.run == 1 and game.phase == "run" and game.run_time == 0.0, "game starts in run 1")
    game.run_time = 30.0
    game.frame(dt)
    check(absf(game.hud.progress_fill.size.x - 400.0) < 10.0, "progress line is half full at 30 s (%.0f px)" % game.hud.progress_fill.size.x)
    check(game.hud.coin_label.text == "0" and game.hud.coin_icon.visible, "gold coin icon next to the coin counter")
    game.run_time = Game.RUN_SECONDS - 0.01
    game.frame(dt)
    check(game.phase == "run_complete" and game.loadout.coins == Game.RUN_BONUS_PER_RUN, "60 s ends the run and pays a completion bonus")
    check(game.hud.banner.visible and game.hud.banner.text.contains("RUN 1 COMPLETE"), "RUN COMPLETE banner")
    var saw_fade := false
    var n2 := 0
    while game.phase != "shop" and n2 < 600:
        game.frame(dt)
        saw_fade = saw_fade or game.fade > 0.5
        n2 += 1
    check(game.phase == "shop" and saw_fade, "fades to black, then the shop opens (%d ticks)" % n2)
    for i in 40:
        game.frame(dt)
    check(game.fade == 0.0 and game.hud.overlay.visible, "fades back in on the shop screen")
    var rows: Array = game._shop_rows()
    check(rows[rows.size() - 1]["id"] == Shop.NEXT_RUN_ROW, "last shop row starts the next run")
    game.loadout.coins = 40
    game.shop_selection = 1
    var enter := InputEventAction.new()
    enter.action = "ui_accept"
    enter.pressed = true
    game._menu_input(enter)
    check(game.loadout.owns("spread"), "ENTER in the shop buys the selected weapon")
    game.shop_selection = rows.size() - 1
    game._input(enter)
    var n3 := 0
    while not (game.phase == "run" and game.run == 2 and game.fade_dir == 0) and n3 < 600:
        game.frame(dt)
        n3 += 1
    check(game.run == 2 and game.phase == "run" and game.run_time < 0.1, "leaving the shop starts run 2")
    check(game.scroll_speed > Cfg.SCROLL_SPEED and game.gap_factor < 1.0, "run 2 is harder (speed %.2f, gap x%.2f)" % [game.scroll_speed, game.gap_factor])
    check(game.loadout.owns("spread") and game.weapon == "spread", "purchases carry into the next run")

    print("boss run")
    game.new_game()
    game.run = 3
    game.start_run()
    _quiet(game)
    game.run_time = Game.RUN_SECONDS - 0.01
    game.frame(dt)
    check(game.boss_spawned and game.boss != null and game.phase == "run", "run 3 ends with a boss, not a fade")
    check(game.acorns >= Game.BOSS_AMMO and game.hud.boss_bg.visible, "boss arrives with ammo and a health bar")
    var boss: Enemy = game.boss
    var hp0 := boss.hp
    game._damage_enemy(boss, 1)
    check(boss.hp == hp0 - 1 and not boss.defeated, "the boss takes hits")
    var fired := false
    var charged := false
    for i in 600:
        game.frame(dt)
        fired = fired or game.enemy_shots.size() > 0
        charged = charged or boss.boss_state == "charge"
        if game.squirrel.game_over:
            break
    check(fired, "the boss spits fireballs while it stands")
    # (the fireball kills a motionless squirrel, so it is cleared here to watch the charge)
    game.new_game()
    game.run = 3
    game.start_run()
    _quiet(game)
    game.run_time = Game.RUN_SECONDS - 0.01
    game.frame(dt)
    boss = game.boss
    for i in 600:
        game._clear(game.enemy_shots)
        game.frame(dt)
        charged = charged or boss.boss_state == "charge"
        if boss.boss_state == "charge":
            break
    check(charged, "the boss then blinks and charges")
    game.new_game()
    game.run = 3
    game.start_run()
    _quiet(game)
    game.run_time = Game.RUN_SECONDS - 0.01
    game.frame(dt)
    game._damage_enemy(game.boss, 999)
    var coins_before: int = game.loadout.coins
    game.frame(dt)
    check(game.phase == "run_complete" and game.complete_boss, "defeating the boss completes the run")
    check(game.loadout.coins >= coins_before + Game.RUN_BONUS_PER_RUN * 3 and game.score >= 10, "boss pays coins and 10 points")
    check(not Game.is_boss_run(1) and not Game.is_boss_run(2) and Game.is_boss_run(3) and Game.is_boss_run(6), "every 3rd run is a boss run")


    print("smarter enemies: movement")
    var tgt := Rect2(50.0, 460.0, 40.0, 40.0)  # the squirrel
    var bird := Enemy.create("bird", 600.0, 300.0)
    var y_lo := 1e9
    var y_hi := -1e9
    for i in 180:
        bird.update(0.0, dt, tgt)
        y_lo = minf(y_lo, bird.y)
        y_hi = maxf(y_hi, bird.y)
    check(y_hi - y_lo > 50.0, "birds fly in a sine wave (%.0f px)" % (y_hi - y_lo))

    var charger := Enemy.create("beaver", 500.0, 420.0)
    var seen: Array[String] = []
    var fastest := 0.0
    for i in 300:
        var cx0 := charger.x
        charger.update(3.0, dt, tgt)
        if seen.is_empty() or seen[seen.size() - 1] != charger.ai_state:
            seen.append(charger.ai_state)
        fastest = maxf(fastest, cx0 - charger.x)
    check(seen == ["cruise", "telegraph", "go"], "beaver: walks, blinks, then charges %s" % [seen])
    check(fastest > 8.0, "...and the charge is fast (%.1f px/tick)" % fastest)

    var diver := Enemy.create("ptero", 650.0, 100.0)
    var dived := false
    for i in 240:
        diver.update(3.0, dt, tgt)
        dived = dived or (diver.ai_state == "go" and diver.vy > 0.0)
    check(dived and diver.y > 250.0, "pterodactyl telegraphs then dives at the squirrel (y=%.0f)" % diver.y)

    var hopper := Enemy.create("croco", 600.0, 420.0)
    var hop_top := 1e9
    for i in 240:
        hopper.update(0.0, dt, tgt)
        hop_top = minf(hop_top, hopper.y)
    check(hop_top < 420.0 - 30.0, "croco leaps (%.0f px high)" % (420.0 - hop_top))

    var digger := Enemy.create("mole", 600.0, 440.0)
    var up_at := -1.0
    for i in 400:
        digger.update(3.0, dt, tgt)
        if not digger.underground:
            up_at = digger.rect().position.x - tgt.end.x
            break
    check(up_at > 0.0 and up_at < 200.0, "mole tunnels toward the squirrel and surfaces just ahead (%.0f px)" % up_at)


    print("new opponents (milestone 3)")
    for entry in [["bee", Game.BEE_FROM_RUN, 3], ["hedgehog", Game.HEDGEHOG_FROM_RUN, 1], ["fox", Game.FOX_FROM_RUN, 1], ["owl", Game.OWL_FROM_RUN, 1]]:
        var nm: String = entry[0]
        var from_run: int = entry[1]
        var counts: Array[int] = []
        for r: int in [from_run - 1, from_run]:
            game.new_game()
            game.run = r
            game.start_run()
            _quiet(game)
            game.set("next_" + nm, 0.0)
            game._spawn_ground_enemies()
            game._spawn_flyers()
            counts.append(game.enemies.filter(func(e: Enemy) -> bool: return e.kind == nm).size())
        check(counts[0] == 0 and counts[1] == entry[2], "%s: absent in run %d, appears in run %d (x%d)" % [nm, from_run - 1, from_run, counts[1]])
    for nm in ["hedgehog", "fox", "owl", "bee"]:
        var en := Enemy.create(nm, 0.0, 0.0)
        var ratio_ok := true
        for f: String in en.cfg["frames"]:
            var tx: Texture2D = Cfg.tex(f)
            ratio_ok = ratio_ok and absf(float(tx.get_width()) / tx.get_height() / (en.w / en.h) - 1.0) < 0.06
        check(ratio_ok and en.rect().size.x < en.w and en.rect().size.y < en.h, "%s: own artwork, undistorted, tight hitbox" % nm)

    var hh := Enemy.create("hedgehog", 500.0, 450.0)
    var hh_seen: Array[String] = []
    var hh_fast := 0.0
    for i in 300:
        var hx0 := hh.x
        hh.update(3.0, dt, tgt)
        if hh_seen.is_empty() or hh_seen[hh_seen.size() - 1] != hh.ai_state:
            hh_seen.append(hh.ai_state)
        hh_fast = maxf(hh_fast, hx0 - hh.x)
    check(hh_seen == ["cruise", "telegraph", "ball"] and hh.curled and hh.frame_idx == 2, "hedgehog: walks, tucks in, then rolls as a ball %s" % [hh_seen])
    check(hh_fast > 7.0, "...fast (%.1f px/tick)" % hh_fast)
    game.new_game()
    _quiet(game)
    var ball := Enemy.create("hedgehog", 300.0, 450.0)
    ball.curled = true
    game.layers["ground"].add_child(ball)
    game.enemies.append(ball)
    var bounce := Shot.create("acorn", 310.0, 470.0)
    game._shot_hits_enemies(bounce)
    check(ball.hp == 2 and not bounce.active, "acorns bounce off a rolled-up hedgehog")
    var pierce_shot := Shot.create("rainbow", 310.0, 470.0)
    game._shot_hits_enemies(pierce_shot)
    check(ball.defeated, "...but the rainbow beam cuts through")

    var fx_enemy := Enemy.create("fox", 600.0, 440.0)
    var fx_seen: Array[String] = []
    var fx_top := 1e9
    for i in 300:
        fx_enemy.update(3.0, dt, tgt)
        if fx_seen.is_empty() or fx_seen[fx_seen.size() - 1] != fx_enemy.ai_state:
            fx_seen.append(fx_enemy.ai_state)
        fx_top = minf(fx_top, fx_enemy.y)
    check(fx_seen == ["cruise", "telegraph", "air", "run"] and fx_top < 440.0 - 40.0, "fox: runs fast, crouches, pounces (%.0f px high) %s" % [440.0 - fx_top, fx_seen])

    var owl_e := Enemy.create("owl", 600.0, 270.0)
    var owl_lo := 1e9
    var owl_hi := -1e9
    for i in 360:
        owl_e.update(0.0, dt, tgt)
        owl_lo = minf(owl_lo, owl_e.y)
        owl_hi = maxf(owl_hi, owl_e.y)
    check(owl_hi - owl_lo > 150.0, "owl: slow wide swoops (%.0f px)" % (owl_hi - owl_lo))
    var bee_e := Enemy.create("bee", 600.0, 300.0)
    var bee_lo := 1e9
    var bee_hi := -1e9
    for i in 120:
        bee_e.update(0.0, dt, tgt)
        bee_lo = minf(bee_lo, bee_e.y)
        bee_hi = maxf(bee_hi, bee_e.y)
    check(bee_hi - bee_lo > 80.0 and bee_e.hp == 1, "bee: fast zigzag, one hit kills (%.0f px)" % (bee_hi - bee_lo))

    print("smarter enemies: protection")
    game.new_game()
    _quiet(game)
    var sb := Enemy.create("beaver", 300.0, 420.0)
    sb.shielded = true
    game.layers["ground"].add_child(sb)
    game.enemies.append(sb)
    var front := Shot.create("acorn", 300.0, 440.0)
    game._shot_hits_enemies(front)
    check(sb.hp == 2 and not front.active, "a shield stops acorns from the front")
    var boom2 := Shot.create("boomerang", 280.0, 440.0)
    game._shot_hits_enemies(boom2)
    check(sb.hp == 2 and boom2.returning and boom2.vx < 0.0, "a boomerang bounces off the shield")
    var back := Shot.create("boomerang", 300.0, 440.0)
    back.vx = -9.0
    game._shot_hits_enemies(back)
    check(sb.hp == 1, "...but hits from behind on the way back")
    sb.hp = 2
    var beam2 := Shot.create("rainbow", 280.0, 440.0)
    game._shot_hits_enemies(beam2)
    check(sb.defeated, "the rainbow beam breaks shields")
    var sb2 := Enemy.create("beaver", 300.0, 420.0)
    sb2.shielded = true
    game.layers["ground"].add_child(sb2)
    game.enemies.append(sb2)
    var bomb2 := Shot.create("pinecone", 300.0, 440.0)
    game._add_shot(bomb2)
    bomb2.detonate()
    game._update_shots()
    check(sb2.defeated, "a pinecone blast ignores the shield")

    var armored := Enemy.create("beaver", 0.0, 0.0)
    armored.scale_for_run(7)
    check(armored.hp == 4 and armored.max_hp == 4 and armored.speed_mult > 1.2, "later runs: armor (+hp) and speed (hp %d)" % armored.hp)
    armored.hit(1)
    check(not armored.enraged, "...not angry yet")
    armored.hit(1)
    check(armored.enraged and armored.flash > 0.0, "...enraged (faster) below half hp, with a hit flash")
    var calm := Enemy.create("beaver", 0.0, 0.0)
    calm.scale_for_run(3)
    calm.hp = 4
    calm.max_hp = 4
    calm.hit(3)
    check(not calm.enraged, "no enraged enemies before run 4, however wounded")
    var wounded_boss := Enemy.create_boss(0, 0.0, 0.0)
    wounded_boss.scale_for_run(3)
    wounded_boss.hit(wounded_boss.hp - 1)
    check(not wounded_boss.enraged, "...bosses included (run 3)")
    var angry := Enemy.create("beaver", 0.0, 0.0)
    angry.scale_for_run(4)
    angry.hit(angry.hp - 1)  # one hp left of three
    check(angry.enraged, "from run 4 a wounded enemy gets enraged")
    var shielded_seen := false
    for i in 120:
        var cand := Enemy.create("beaver", 0.0, 0.0)
        cand.scale_for_run(Enemy.SHIELD_FROM_RUN - 1)
        check_no_shield_run2(cand)
        var c6 := Enemy.create("beaver", 0.0, 0.0)
        c6.scale_for_run(Enemy.SHIELD_FROM_RUN)
        shielded_seen = shielded_seen or c6.shielded
    check(shielded_seen and not _shield_leak, "protected (shielded) enemies only from run 7")

    print("smarter enemies: shooting")
    var sk_a := Enemy.create("skunk", 0.0, 0.0)
    sk_a.scale_for_run(2)
    var sk_b := Enemy.create("skunk", 0.0, 0.0)
    sk_b.scale_for_run(3)
    var bd_a := Enemy.create("bird", 0.0, 0.0)
    bd_a.scale_for_run(3)
    var bd_b := Enemy.create("bird", 0.0, 0.0)
    bd_b.scale_for_run(4)
    var pt_a := Enemy.create("ptero", 0.0, 0.0)
    pt_a.scale_for_run(4)
    var pt_b := Enemy.create("ptero", 0.0, 0.0)
    pt_b.scale_for_run(5)
    check(not sk_a.can_shoot and sk_b.can_shoot and not bd_a.can_shoot and bd_b.can_shoot and not pt_a.can_shoot and pt_b.can_shoot, "nobody shoots in the first runs: skunk 3+, bird 4+, ptero 5+")
    game.new_game()
    game.run = 3
    game.start_run()
    _quiet(game)
    var gs := Enemy.create("skunk", 600.0, 430.0)
    gs.scale_for_run(3)
    gs.shoot_cd = 0.0
    game.layers["ground"].add_child(gs)
    game.enemies.append(gs)
    var sprayed := false
    for i in 600:
        game.frame(dt)
        if game.enemy_shots.size() > 0:
            sprayed = game.enemy_shots[0].kind == "gas"
            break
    check(sprayed, "a skunk sprays a gas cloud from run 3")
    game.new_game()
    _quiet(game)
    var gas := EnemyShot.create("gas", game.squirrel.x + 20.0, game.squirrel.y + 20.0)
    game.layers["shots"].add_child(gas)
    game.enemy_shots.append(gas)
    game.frame(dt)
    check(game.squirrel.game_over, "touching a projectile is lethal")
    game.new_game()
    _quiet(game)
    var gas2 := EnemyShot.create("gas", 400.0, 470.0)
    game.layers["shots"].add_child(gas2)
    game.enemy_shots.append(gas2)
    var acorn_shot := Shot.create("acorn", 395.0, 470.0)
    game._shot_hits_enemy_shots(acorn_shot)
    check(not gas2.active and not acorn_shot.active, "an acorn shoots down a projectile")
    var egg := EnemyShot.create("egg", 400.0, 300.0)
    for i in 120:
        egg.update(dt)
    check(not egg.active, "eggs fall and splat on the ground")

    print("Matrix Fist")
    check(is_equal_approx(Game.fist_time_scale(0.0), 1.0) and is_equal_approx(Game.fist_time_scale(1.0), Game.FIST_SLOW)
        and is_equal_approx(Game.fist_time_scale(3.0), Game.FIST_SLOW) and is_equal_approx(Game.fist_time_scale(5.0), 1.0)
        and Game.fist_time_scale(0.5) < 1.0 and Game.fist_time_scale(0.5) > Game.FIST_SLOW and Game.fist_time_scale(4.5) < 1.0, "time curve: slow down 0-1 s, hold, back to normal 4-5 s")
    game.new_game()
    _quiet(game)
    check(not game.use_fist(), "no charge: nothing happens")
    game.loadout.coins = 100
    check(Shop.activate(game.loadout, Shop.FIST_ROW).begins_with("Bought") and game.loadout.fists == 3 and game.loadout.coins == 100 - Weapons.FIST_PRICE, "one Matrix Fist purchase gives 3 charges")
    var fr: Array = game._shop_rows().filter(func(r: Dictionary) -> bool: return r["id"] == Shop.FIST_ROW)
    check(fr[0]["name"].contains("owned 3"), "the shop shows how many you own")
    game.frame(dt)
    check(game.hud.fist_icon.visible and game.hud.fist_label.text.begins_with("x3"), "the HUD shows a fist with the count")
    var victim := Enemy.create("beaver", 420.0, 420.0)
    victim.hp = 3
    victim.max_hp = 3
    victim.shielded = true  # the fist ignores shields
    game.layers["ground"].add_child(victim)
    game.enemies.append(victim)
    check(game.use_fist() and game.loadout.fists == 2 and game.fist_active, "F spends a charge and starts the sequence")
    var min_ts := 1.0
    var max_x := 0.0
    var ghosts_seen := 0
    var tint_seen := 0.0
    var defeated_at := -1.0
    var invuln_ok := true
    var min_sq_y := 1e9
    var max_dim := 0.0
    for i in 330:
        game.frame(dt)
        min_sq_y = minf(min_sq_y, game.squirrel.y)
        max_dim = maxf(max_dim, game.hud.matrix_dim.color.a)
        min_ts = minf(min_ts, Cfg.time_scale)
        max_x = maxf(max_x, game.squirrel.x)
        ghosts_seen = maxi(ghosts_seen, game.ghosts.size())
        tint_seen = maxf(tint_seen, game.hud.matrix_tint.color.a)
        if victim.defeated and defeated_at < 0.0:
            defeated_at = game.fist_t if game.fist_active else 5.0
        invuln_ok = invuln_ok and not game.squirrel.game_over
    check(absf(min_ts - Game.FIST_SLOW) < 0.01, "the world slows to %.0f%% speed" % (min_ts * 100.0))
    check(max_x > 650.0, "the squirrel dashes across the whole screen (to x=%.0f)" % max_x)
    check(ghosts_seen >= 3, "with a ghost trail (%d afterimages)" % ghosts_seen)
    check(victim.defeated and defeated_at >= 2.0 and defeated_at < 3.0, "the dash punches it for 3 damage on the way out, through the shield (t=%.2f)" % defeated_at)
    check(absf(game.squirrel.x - Squirrel.START_X) < 0.5 and not game.fist_active and Cfg.time_scale == 1.0, "back in place at normal speed after 5 s")
    check(tint_seen > 0.1 and game.hud.matrix_tint.color.a < 0.01, "matrix tint fades in and out")
    check(invuln_ok, "no damage taken during the sequence")
    check(min_sq_y >= game.squirrel.ground_y - 0.5, "the squirrel never rises above a ground target (min y %.1f)" % min_sq_y)
    check(max_dim > 0.3 and game.hud.matrix_dim.color.a < 0.01, "the light dims (%.2f) and comes back at the end" % max_dim)

    # it doesn't stop at the first thing: everything on the way is hit, on both legs
    game.new_game()
    _quiet(game)
    game.loadout.fists = 1
    var first := Enemy.create("skunk", 250.0, 420.0)
    var tough := Enemy.create("beaver", 450.0, 420.0)
    tough.hp = 6
    tough.max_hp = 6
    tough.shielded = true
    var wood := TreeProp.new()
    wood.place(600.0, 425.0)
    var shooter := Enemy.create("bird", 700.0, 380.0)
    for en in [first, tough, shooter]:
        game.layers["air" if en.air else "ground"].add_child(en)
        game.enemies.append(en)
    game.layers["trees"].add_child(wood)
    game.trees.append(wood)
    game.use_fist()
    var hp_at_turn := -1
    var all_out := false
    for i in 330:
        game.frame(dt)
        if hp_at_turn < 0 and game.fist_t >= Game.FIST_PUNCH_AT:
            hp_at_turn = tough.hp
            all_out = first.defeated and not wood.active
    check(all_out, "the dash goes past the first enemy: skunk beaten and tree smashed on the way out")
    check(hp_at_turn == 3, "a tough enemy takes 3 damage per leg, not per tick (hp %d at the turnaround)" % hp_at_turn)
    check(tough.defeated, "...and the return leg hits everything again (3 + 3 = dead)")
    check(not game.squirrel.game_over and Cfg.time_scale == 1.0, "the squirrel is back, unharmed")

    # a flying target: the squirrel dashes up to its height, then comes back down
    game.new_game()
    _quiet(game)
    game.loadout.fists = 1
    var flyer := Enemy.create("bird", 420.0, 300.0)
    game.layers["air"].add_child(flyer)
    game.enemies.append(flyer)
    game.use_fist()
    var flyer_min_y := 1e9
    for i in 330:
        game.frame(dt)
        flyer_min_y = minf(flyer_min_y, game.squirrel.y)
    check(flyer.defeated and flyer_min_y < 400.0 and absf(game.squirrel.y - game.squirrel.ground_y) < 1.0, "it flies up to a bird's height (y %.0f), punches it and lands back" % flyer_min_y)

    # trees can be smashed too
    game.new_game()
    _quiet(game)
    game.loadout.fists = 1
    var smash := TreeProp.new()
    smash.place(420.0, 425.0)
    game.layers["trees"].add_child(smash)
    game.trees.append(smash)
    game.use_fist()
    var coins0: int = game.loadout.coins
    for i in 330:
        game.frame(dt)
    check(not smash.active or not game.trees.has(smash), "the fist smashes a tree")
    check(game.loadout.coins == coins0 + Game.TREE_COINS and not game.squirrel.game_over, "...for a couple of coins, without harm")
    game.new_game()
    _quiet(game)
    game.loadout.fists = 1
    game.use_fist()
    for i in 30:
        game.frame(dt)
    var t_before: float = game.fist_t
    game.pause()
    for i in 30:
        game.frame(dt)
    check(game.fist_t == t_before, "pausing freezes the sequence")
    game.resume()
    game.new_game()
    check(Cfg.time_scale == 1.0 and not game.fist_active, "a new game resets the slow-motion")


    print("lives")
    game.new_game()
    _quiet(game)
    game.frame(dt)
    var shown: Array = game.hud.life_icons.filter(func(i: TextureRect) -> bool: return i.visible)
    check(game.loadout.lives == 3 and shown.size() == 3, "3 lives at the start, shown as 3 small squirrels")
    var killer := TreeProp.new()
    killer.place(200.0, 425.0)
    game.layers["trees"].add_child(killer)
    game.trees.append(killer)
    var n5 := 0
    while not game.squirrel.game_over and n5 < 300:
        game.frame(dt)
        n5 += 1
    check(game.squirrel.game_over and game.loadout.lives == 2, "a hit costs one life (%d left)" % game.loadout.lives)
    check(not game.hud.overlay.visible and not game.hud.banner.visible, "no game-over screen while lives remain")
    var run_t: float = game.run_time
    var n6 := 0
    while game.squirrel.game_over and n6 < 200:
        game.frame(dt)
        n6 += 1
    check(not game.squirrel.game_over and game.squirrel.x == Squirrel.START_X and game.run == 1 and game.run_time == run_t, "it gets back up and the run goes on (%d ticks)" % n6)
    check(game.invuln_timer > 2.0, "with a short invulnerability")
    game.frame(dt)
    check(game.trees.is_empty(), "the thing that killed it was cleared away")
    var again := TreeProp.new()
    again.place(160.0, 425.0)
    game.layers["trees"].add_child(again)
    game.trees.append(again)
    for i in 60:
        game.frame(dt)
    check(not game.squirrel.game_over and game.loadout.lives == 2, "invulnerable right after the respawn")

    print("earning lives")
    game.new_game()
    _quiet(game)
    game.loadout.lives = 5
    var heart := LifePickup.new()
    heart.place_on(game.squirrel.x, game.squirrel.y)
    game.layers["rainbow"].add_child(heart)
    game.life_pickups.append(heart)
    game.frame(dt)
    check(game.loadout.lives == 6 and not heart.active, "a 1UP heart gives a life")
    var heart2 := LifePickup.new()
    heart2.place_on(game.squirrel.x, game.squirrel.y)
    game.layers["rainbow"].add_child(heart2)
    game.life_pickups.append(heart2)
    var c_before: int = game.loadout.coins
    game.frame(dt)
    check(game.loadout.lives == Weapons.MAX_LIVES and game.loadout.coins == c_before + 10, "at the maximum (6) a heart pays 10 coins instead")
    game.new_game()
    game.loadout.coins = 100
    check(Shop.activate(game.loadout, Shop.LIFE_ROW) == "Extra life!" and game.loadout.lives == 4 and game.loadout.coins == 100 - Weapons.LIFE_PRICE, "the shop sells extra lives")
    game.loadout.lives = 6
    check(Shop.activate(game.loadout, Shop.LIFE_ROW).contains("maximum") and game.loadout.lives == 6, "...up to a maximum of 6")
    game.new_game()
    game.run = 3
    game.start_run()
    _quiet(game)
    game.run_time = Game.RUN_SECONDS - 0.01
    game.frame(dt)
    game._damage_enemy(game.boss, 999)
    game.frame(dt)
    check(game.complete_life and game.loadout.lives == 4 and game.hud.banner.text.contains("+1 life"), "defeating a boss earns a life")
    check(Enemy.KINDS["skunk"]["coins"] >= 3 and Enemy.KINDS["ptero"]["coins"] >= 8 and Enemy.KINDS["croco"]["coins"] > Enemy.KINDS["skunk"]["coins"], "kills pay more, depending on the opponent")

    print("pause menu (ESC)")
    game.new_game()
    _quiet(game)
    var esc := InputEventAction.new()
    esc.action = "ui_cancel"
    esc.pressed = true
    game._input(esc)
    check(game.paused and game.menu_state == "pause", "ESC pauses")
    var off: float = game.scroll_offset
    for i in 30:
        game.frame(dt)
    check(game.scroll_offset == off and game.hud.overlay.visible, "the world is frozen while paused")
    var pids: Array = game.menu_items().map(func(i: Dictionary) -> String: return i["id"])
    check(pids.slice(0, 3) == ["continue", "restart", "language"] and pids.has("quit"), "pause menu: continue, restart, language, controls, quit")
    game._input(esc)
    check(not game.paused, "ESC again continues")
    game._input(esc)
    game.loadout.coins = 7
    game.menu_selection = 1  # restart
    game._input(enter)
    var n4 := 0
    while (game.paused or game.loadout.coins != 0) and n4 < 300:
        game.frame(dt)
        n4 += 1
    check(not game.paused and game.loadout.coins == 0 and game.run == 1, "Restart starts a fresh game")

    print("language")
    check(Lang.current == "en" and Lang.t("Restart") == "Restart", "english by default in tests")
    game.toggle_language()
    check(Lang.current == "fr" and Lang.t("Restart") == "Recommencer", "language switches to french")
    check(Lang.t("Run %d", [2]) == "Run 2" and Lang.t("RUN %d", [2]) == "MANCHE 2", "formatting + fallback to english")
    var fr_ids: Array = game.menu_items().filter(func(i: Dictionary) -> bool: return i["id"] == "language")
    check(fr_ids[0]["text"] == "Langue : Français", "menu shows the language in its own name")
    check(Shop.rows(game.loadout, 2, false)[0]["status"] == "ÉQUIPÉ", "shop is translated")
    var reload := Profile.new()
    reload.load_from_disk()
    check(reload.language == "fr" and Lang.current == "fr", "chosen language is saved")
    for w in Weapons.ORDER:
        check(Lang.FR.has(Weapons.DEFS[w]["name"]) and Lang.FR.has(Weapons.DEFS[w]["desc"]), "french text for weapon %s" % w)
    game.toggle_language()
    check(Lang.current == "en", "...and back to english")

    print("shop UI")
    game.new_game()
    game._enter_shop()
    game.frame(dt)
    check(game.hud.overlay.visible and game.hud.menu_root.get_child_count() > 15, "shop screen renders (%d nodes)" % game.hud.menu_root.get_child_count())
    var down := InputEventAction.new()
    down.action = "ui_down"
    down.pressed = true
    game._menu_input(down)
    check(game.shop_selection == 1, "Down moves the shop selection")
    game.new_game()

    DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
    print("")
    print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
    quit(1 if failures > 0 else 0)
