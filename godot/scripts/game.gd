class_name Game
extends Node2D
## Main game. A *game* is a series of timed *runs*:
##   run (60 s, harder every time; a boss ends every 3rd run)
##     -> fade -> shop (spend coins) -> fade -> next run ... until you die.
## Coins, weapons and upgrades (Loadout) last for one game only; best score,
## furthest run and the language (Profile) are saved.
## One fixed 60 Hz `frame()` per physics tick, in the same order as the
## original prototype's main loop so the feel is identical.

const MENU_DELAY := 3.0      # seconds of "GAME OVER" before the menu appears
const RUN_SECONDS := 60.0
const BOSS_EVERY := 3        # every 3rd run ends with a boss
const BOSS_AMMO := 12        # acorns topped up to this when the boss arrives
const RUN_BONUS_PER_RUN := 5 # completion bonus = this x run number (coins)
const COMPLETE_DELAY := 1.8  # "RUN COMPLETE" banner time before the fade
const RESPAWN_DELAY := 1.4   # seconds lying down before getting back up (lives left)
const INVULN_TIME := 2.5     # blinking invulnerability after a respawn
const ARMOR_BREAK_GRACE := 1.5  # ...and after the Diver Armor breaks
const FLASH_TIME := 0.22     # the white flash at the start of an explosion
const FLASH_STRENGTH := 0.65
const FADE_TIME := 0.45
const ANNOUNCE_TIME := 2.0
## The boss goes down in a string of big explosions: [seconds after the kill, offset from its
## centre as a fraction of its size, blast radius]. The first is bigger than any chestnut.
const BOSS_BLASTS := [[0.0, Vector2(0.0, 0.0), 130.0], [0.25, Vector2(-0.3, -0.15), 90.0],
    [0.45, Vector2(0.3, 0.1), 95.0], [0.65, Vector2(-0.1, 0.25), 90.0], [0.85, Vector2(0.15, -0.25), 110.0]]
const BOSS_VICTORY_TIME := 2.0  # the game keeps running this long after the boss falls, before the run ends

# Matrix Fist timeline (real seconds): the attack starts at second 0 - the squirrel
# dashes out across the whole screen (0-1.5 s) and back (1.5-3 s), punching
# everything on the way (once per leg). Meanwhile the world slows down (0-1 s),
# stays slow, and speeds back up (3-4 s). The whole thing lasts 4 seconds.
const FIST_DURATION := 4.0
const FIST_SLOW := 0.1       # world speed at the bottom of the slow-down
const FIST_DASH_AT := 0.0    # the attack starts immediately
const FIST_TURN_AT := 1.5    # far end reached, dash back
const FIST_BACK_AT := 3.0    # back in place; the world speeds up again until 4 s
const FIST_LEG := FIST_TURN_AT - FIST_DASH_AT
const FIST_REACH := 50.0     # how far in front of the squirrel the fist reaches
const FIST_PAD := 10.0       # extra height above/below the squirrel that still gets hit
const FIST_END_X := Cfg.SCREEN_W - 50.0  # the far end of the dash (screen's right side)
const BOX_COINS := 2
const RAINBOW_COINS := 5
const TREE_COINS := 2        # coins for smashing a tree with the fist

# spawn gaps in scroll-offset units (base .. base + extra)
const BOX_SPAWN_DISTANCE := 1200
const TREE_SPAWN_DISTANCE := 1500
const SKUNK_SPAWN_DISTANCE := 2000
const BEAVER_SPAWN_DISTANCE := 1700
const MOLE_SPAWN_DISTANCE := 1800
const BIRD_SPAWN_DISTANCE := 1500
const PTERO_SPAWN_DISTANCE := 2000
# opponents join the mix as the runs go on
const BEAVER_FROM_RUN := 2
const MOLE_FROM_RUN := 3
const CROCO_FROM_RUN := 4
const CROCO_SPAWN_DISTANCE := 2300
const BEE_FROM_RUN := 8          # swarms of 3
const BEE_SPAWN_DISTANCE := 1700
const RACCOON_FROM_RUN := 9     # needs its (local-only) art: see Enemy.is_available
const RACCOON_SPAWN_DISTANCE := 2600
const OWL_FROM_RUN := 7
const OWL_SPAWN_DISTANCE := 2800

const LAYERS := ["trees", "ground", "air", "clouds", "rainbow", "boxes", "popups", "player", "shots"]

# --- game state (whole game) ---
var profile := Profile.new()   # saved: best score / run, language
var loadout := Loadout.new()   # this game only: coins, weapons, upgrades
var run := 1
var score := 0
var phase := "run"             # "run" | "run_complete" | "shop"
var paused := false

# --- run state ---
var acorns := Weapons.START_AMMO
var weapon := "acorn"          # equipped weapon id (see Weapons)
var armored := false           # wearing the Diver Armor: no jump, harpoons, armor_hp health points
var armor_hp := 0              # Weapons.ARMOR_HP at the start of an armored run; at 0 the armor breaks
var run_time := 0.0
var scroll_speed := Cfg.SCROLL_SPEED
var gap_factor := 1.0          # < 1 = enemies spawn closer together
var scroll_offset := 0.0
var boss: Enemy = null
var boss_spawned := false
var boss_blasts_fired := 0     # how many of BOSS_BLASTS have gone off
var boss_down_time := -1.0     # seconds since the boss was defeated (-1 = still standing)
var complete_timer := 0.0
var complete_bonus := 0
var complete_boss := false
var complete_life := false
var announce_text := ""
var announce_timer := 0.0

var next_box := 200.0
var next_tree := 500.0
var next_skunk := 1000.0
var next_beaver := 1000.0
var next_mole := 1200.0
var next_croco := 1500.0
var next_bee := 1400.0
var next_raccoon := 2000.0
var next_owl := 1800.0
var next_bird := 800.0
var next_ptero := 1500.0
var last_box_spawn := -INF
var last_tree_spawn := -INF

var over_started := false
var over_elapsed := 0.0
var invuln_timer := 0.0
var next_life := INF          # scroll offset where this run's 1UP heart shows up
var life_spawned := false

# --- Matrix Fist ---
var fist_active := false
var fist_t := 0.0
var fist_x0 := Squirrel.START_X
var fist_x1 := Squirrel.START_X
var fist_y0 := 0.0
var fist_y1 := 0.0
var fist_dash_started := false
var fist_turned := false      # the return leg has begun
var fist_hit := {}            # instance ids already punched on this leg
var _ghost_tick := 0

# --- menus / transitions ---
var menu_state := "main"       # "main" (game over) | "pause" | "shop" | "controls"
var controls_return := "main"
var menu_selection := 0
var shop_selection := 0
var shop_message := ""
var shop_mood := "idle"        # the dwarf: "idle" | "happy" (after a purchase)
var flash := 0.0               # 1 = just exploded: the screen flashes white, then fades back
var fade := 0.0                # 0 = clear, 1 = black
var fade_dir := 0              # +1 fading out, -1 fading in, 0 idle
var _fade_action := Callable()

# --- world ---
var squirrel: Squirrel
var background: Background
var hud: Hud
var audio: AudioHub
var layers := {}
var _was_jumping := false
var _fist_end_played := false

var shots: Array[Shot] = []
var boxes: Array[Box] = []
var trees: Array[TreeProp] = []
var enemies: Array[Enemy] = []
var ridden: Enemy = null       # the bird the squirrel is riding (it keeps its place on screen until the next jump)
var enemy_shots: Array[EnemyShot] = []
var ghosts: Array[Ghost] = []
var punch_fx: Array[PunchFx] = []
var popups: Array[PopupAcorn] = []
var clouds: Array[Cloud] = []
var rainbows: Array[RainbowAcorn] = []
var life_pickups: Array[LifePickup] = []


func _ready() -> void:
    randomize()
    profile.load_from_disk()
    _setup_input()
    # Exported macOS app runs full screen; editor / `make run` stay windowed
    # and the web build is sized by the browser page.
    if OS.get_name() == "macOS" and OS.has_feature("template"):
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

    background = Background.new()
    add_child(background)
    for layer_name: String in LAYERS:
        var n := Node2D.new()
        n.name = layer_name
        add_child(n)
        layers[layer_name] = n

    squirrel = Squirrel.new()
    layers["player"].add_child(squirrel)

    hud = Hud.new()
    add_child(hud)

    audio = AudioHub.new()
    audio.music_volume = profile.music_volume
    audio.sfx_volume = profile.sfx_volume
    add_child(audio)

    new_game()


func _setup_input() -> void:
    _add_key_action("jump", KEY_SPACE)
    _add_key_action("throw", KEY_SHIFT)
    _add_key_action("weapon", KEY_Q)
    _add_key_action("chestnut", KEY_D)
    _add_key_action("fist", KEY_F)


func _add_key_action(action: String, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode
    InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- lifecycle

## Brand new game: no coins, no weapons, no upgrades, run 1.
func new_game() -> void:
    loadout = Loadout.new()
    run = 1
    score = 0
    paused = false
    start_run()


static func is_boss_run(run_number: int) -> bool:
    return run_number % BOSS_EVERY == 0


## Reset the world for `run` (difficulty scales with the run number).
func start_run() -> void:
    phase = "run"
    paused = false
    run_time = 0.0
    scroll_offset = 0.0
    boss = null
    boss_spawned = false
    boss_down_time = -1.0
    boss_blasts_fired = 0
    announce_text = ""
    announce_timer = 0.0
    acorns = loadout.acorns_for_next_run()  # kept from the previous run (see Loadout)
    armored = loadout.armor_ready  # worn for this whole run, then spent
    loadout.armor_ready = false
    armor_hp = Weapons.ARMOR_HP if armored else 0
    weapon = "harpoon" if armored else loadout.equipped
    var d := float(run - 1)
    scroll_speed = Cfg.SCROLL_SPEED + 0.25 * minf(d, 8.0)
    gap_factor = 1.0 / (1.0 + 0.12 * d)
    next_box = 200.0
    next_tree = 500.0
    next_skunk = 1000.0
    next_beaver = 1000.0
    next_mole = 1200.0
    next_croco = 1500.0
    next_bee = 1400.0
    next_raccoon = 2000.0
    next_owl = 1800.0
    next_bird = 800.0
    next_ptero = 1500.0
    last_box_spawn = -INF
    last_tree_spawn = -INF
    _end_fist()
    over_started = false
    over_elapsed = 0.0
    menu_state = "main"
    menu_selection = 0
    shop_message = ""

    _clear(shots)
    _clear(boxes)
    _clear(trees)
    _clear(enemies)
    ridden = null
    _clear(enemy_shots)
    _clear(ghosts)
    _clear(punch_fx)
    _clear(popups)
    _clear(clouds)
    _clear(rainbows)
    _clear(life_pickups)
    invuln_timer = 0.0
    life_spawned = false
    # about every other run hides a 1UP heart on the top cloud row
    next_life = float(randi_range(2500, 7500)) if randf() < 0.5 else INF

    for row_y: float in Cfg.CLOUD_ROWS:
        var cx := 0.0
        while cx < Cfg.SCREEN_W + 200:
            var c := _spawn_cloud(cx, row_y)
            cx += c.w + Cfg.CLOUD_SPACING

    squirrel.reset()
    squirrel.set_diver(armored)
    squirrel.armor_frac = 1.0
    background.set_scroll(0.0)


func _clear(list: Array) -> void:
    for item: Node in list:
        item.queue_free()
    list.clear()


func _drop(list: Array, item: Node) -> void:
    list.erase(item)
    item.queue_free()


## Called every tick of a live run: the 60 s clock, the boss and the end of the run.
func _advance_run(delta: float) -> void:
    run_time += delta
    if announce_timer > 0.0:
        announce_timer -= delta
    if boss_spawned:
        # once the boss has fallen the countdown must not depend on its node: it drops off screen
        # (and is freed) after about a second, sometimes before the 2 s are up
        if boss_down_time >= 0.0 or (boss != null and boss.defeated):
            # the world keeps going for a moment so the kill can be enjoyed, then the run ends
            boss_down_time = maxf(boss_down_time, 0.0) + delta
            if boss != null:
                _boss_explosions()
            if boss_down_time >= BOSS_VICTORY_TIME:
                _complete_run(true)
    elif run_time >= RUN_SECONDS:
        if is_boss_run(run):
            _spawn_boss()
        else:
            _complete_run(false)


## Fires the boss's death blasts as their time comes (visual only: no damage).
func _boss_explosions() -> void:
    while boss_blasts_fired < BOSS_BLASTS.size() and boss_down_time >= BOSS_BLASTS[boss_blasts_fired][0]:
        var plan: Array = BOSS_BLASTS[boss_blasts_fired]
        var br := boss.rect()
        var at := br.get_center() + Vector2((plan[1] as Vector2).x * br.size.x, (plan[1] as Vector2).y * br.size.y)
        var sh := Shot.create_blast(at, plan[2])
        _add_shot(sh)
        audio.sfx("boom", 0.1)
        if boss_blasts_fired == 0:
            flash = 1.0
        boss_blasts_fired += 1


func _spawn_boss() -> void:
    boss_spawned = true
    var tier := run / BOSS_EVERY - 1
    boss = Enemy.create_boss(tier, Cfg.SPAWN_X, 0.0)
    boss.scale_for_run(run)  # (bosses only learn to enrage from run 4)
    boss.y = Cfg.SOIL_Y - boss.h
    boss.sync()
    layers["ground"].add_child(boss)
    enemies.append(boss)
    acorns = maxi(acorns, BOSS_AMMO)
    announce_text = Lang.t("WARNING: BOSS!")
    announce_timer = ANNOUNCE_TIME
    audio.sfx("boss_roar", 0.0)


func _complete_run(boss_defeated: bool) -> void:
    _end_fist()
    loadout.carried_acorns = acorns  # the acorns you have now are the ones you start the next run with
    phase = "run_complete"
    complete_timer = 0.0
    complete_boss = boss_defeated
    complete_bonus = RUN_BONUS_PER_RUN * run
    loadout.add_coins(complete_bonus)
    complete_life = boss_defeated and loadout.add_life()  # beating a boss earns a life
    profile.record_game(score, run)
    audio.sfx("boss_defeated" if boss_defeated else "run_complete", 0.0)


func _enter_shop() -> void:
    phase = "shop"
    menu_state = "shop"
    shop_selection = _shop_step(_shop_rows(), -1, 1)  # the first row the player can pay
    shop_mood = "idle"
    shop_message = Lang.t("Welcome! Take a look at my wares.")
    audio.sfx("shop_bell", 0.0)
    audio.speak(shop_message)


func _begin_next_run() -> void:
    run += 1
    start_run()


## Fade to black, run `action` while the screen is black, then fade back in.
func start_fade(action: Callable) -> void:
    if fade_dir != 0:
        return
    audio.sfx("fade", 0.0)
    fade_dir = 1
    _fade_action = action


func _update_fade(delta: float) -> void:
    if fade_dir == 0:
        return
    fade = clampf(fade + fade_dir * delta / FADE_TIME, 0.0, 1.0)
    if fade_dir > 0 and fade >= 1.0:
        var action := _fade_action
        _fade_action = Callable()
        if action.is_valid():
            action.call()
        fade_dir = -1
    elif fade_dir < 0 and fade <= 0.0:
        fade_dir = 0


# ---------------------------------------------------------------- input

## Landing on a bird makes it carry the squirrel (facing right, flying as fast as the world scrolls) until the
## squirrel jumps (or falls, or the bird is shot); then the bird turns back and flies on.
func _update_ride(ghosted: bool) -> void:
    if ridden != null and (ghosted or squirrel.game_over or not ridden.hittable() \
            or squirrel.velocity_y != 0.0 or not squirrel.stands_on([ridden])):
        ridden.set_ridden(false)
        ridden = null
    if ridden != null or ghosted or squirrel.game_over or squirrel.velocity_y != 0.0:
        return
    for e: Enemy in enemies:
        if e.kind == "bird" and e.hittable() and squirrel.stands_on([e]):
            ridden = e
            e.set_ridden(true)
            return


## One-way platforms the squirrel can stand on: clouds, tree tops and live
## opponents (a defeated enemy or a mole underground is not solid).
func _platforms() -> Array:
    var p: Array = []
    p.append_array(clouds)
    p.append_array(trees)
    for e in enemies:
        if e.hittable():
            p.append(e)
    return p


func do_jump() -> void:
    if armored:  # the diver armor is too heavy to jump in
        return
    var before := squirrel.velocity_y
    squirrel.jump(boxes, _platforms())
    if squirrel.velocity_y < before:
        audio.sfx("jump")


func do_throw() -> void:
    var id := weapon
    if Weapons.DEFS[id].has("stock"):
        id = "acorn"  # consumables (the exploding chestnut) have their own key, D
    var cost: int = Weapons.DEFS[id]["ammo"]
    if acorns < cost:
        # not enough ammo for the fancy weapon: fall back to a plain acorn
        id = "acorn"
        cost = 1
        if acorns < cost:
            return
    acorns -= cost
    audio.sfx("throw_" + id)
    var sx := squirrel.muzzle_x()
    var sy := squirrel.muzzle_y()
    match id:
        "spread":
            for dy: float in [-2.5, 0.0, 2.5]:
                _add_shot(Shot.create("acorn", sx, sy, dy))
        _:
            _add_shot(Shot.create(id, sx, sy))


## D: throw one exploding chestnut from the stock (no acorn is spent). False when there is none.
func throw_chestnut() -> bool:
    if loadout.stock_left("chestnut") <= 0 or squirrel.game_over or phase != "run" or paused:
        return false
    loadout.stock["chestnut"] = loadout.stock_left("chestnut") - 1
    audio.sfx("throw_chestnut")
    _add_shot(Shot.create("chestnut", squirrel.muzzle_x(), squirrel.muzzle_y()))
    return true


func _add_shot(s: Shot) -> void:
    layers["shots"].add_child(s)
    shots.append(s)


## Switch to the next owned weapon (Q).
func cycle_weapon() -> void:
    if armored:  # the armor's harpoon gun is the only weapon this run
        return
    var owned: Array[String] = []
    for id in Weapons.ORDER:
        if loadout.owns(id) and not Weapons.DEFS[id].has("stock"):  # consumables have their own key
            owned.append(id)
    weapon = owned[(owned.find(weapon) + 1) % owned.size()]
    loadout.equip(weapon)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and (event.is_echo() or not event.is_pressed()):
        return
    if fade_dir != 0:
        return  # ignore keys while the screen is fading
    if paused or phase == "shop":
        _menu_input(event)
    elif phase == "run":
        if squirrel.game_over:
            if loadout.lives <= 0 and over_elapsed >= MENU_DELAY:
                _menu_input(event)
        elif event.is_action_pressed("ui_cancel"):
            pause()
        elif fist_active:
            pass  # the Matrix Fist sequence has taken over the controls
        elif event.is_action_pressed("jump"):
            do_jump()
        elif event.is_action_pressed("throw"):
            do_throw()
        elif event.is_action_pressed("weapon"):
            cycle_weapon()
        elif event.is_action_pressed("chestnut"):
            throw_chestnut()
        elif event.is_action_pressed("fist"):
            use_fist()


func pause() -> void:
    if phase != "run" or squirrel.game_over:
        return
    audio.sfx("pause", 0.0)
    paused = true
    menu_state = "pause"
    menu_selection = 0


func resume() -> void:
    audio.sfx("ui_back", 0.0)
    paused = false
    menu_state = "main"


## Entries of the pause / game-over menus: [{id, text}].
func menu_items() -> Array[Dictionary]:
    var items: Array[Dictionary] = []
    if menu_state == "pause":
        items.append({"id": "continue", "text": Lang.t("Continue")})
    items.append({"id": "restart", "text": Lang.t("Restart")})
    items.append({"id": "language", "text": Lang.t("Language: %s", [Lang.native_name()])})
    items.append({"id": "music", "text": Lang.t("Music: %d%%", [roundi(profile.music_volume * 100.0)])})
    items.append({"id": "sfx", "text": Lang.t("Effects: %d%%", [roundi(profile.sfx_volume * 100.0)])})
    items.append({"id": "controls", "text": Lang.t("Show Controls")})
    if not OS.has_feature("web"):  # no "quit" in a browser tab
        items.append({"id": "quit", "text": Lang.t("Quit")})
    return items


func toggle_language() -> void:
    profile.set_language(Lang.next_language())


## Change a volume slider by `step` (wraps to 0 after 100 when `wrap`); previews the new level.
func change_volume(which: String, step: float, wrap := false) -> void:
    var v: float = profile.music_volume if which == "music" else profile.sfx_volume
    v = snappedf(v + step, 0.1)
    if v > 1.0001:
        v = 0.0 if wrap else 1.0
    v = clampf(v, 0.0, 1.0)
    if which == "music":
        profile.set_music_volume(v)
        audio.set_music_volume(v)
    else:
        profile.set_sfx_volume(v)
        audio.set_sfx_volume(v)
        audio.sfx("coin", 0.0)


## What the shopkeeper is saying (the same text the speech bubble shows).
func _shop_line(rows: Array[Dictionary]) -> String:
    if shop_message != "":
        return shop_message
    var detail: String = rows[shop_selection]["detail"]
    return detail if detail != "" else Lang.t("Ready for the next run?")


func _shop_rows() -> Array[Dictionary]:
    return Shop.rows(loadout, run + 1, is_boss_run(run + 1))


## Index of the next enabled shop row after `from` in direction `dir` (+1 / -1), wrapping.
## Rows the player cannot pay are skipped; the "start run" row is always enabled.
static func _shop_step(rows: Array[Dictionary], from: int, dir: int) -> int:
    var n := rows.size()
    var i := from
    for _k in n:
        i = posmod(i + dir, n)
        if rows[i]["enabled"]:
            return i
    return from


func _menu_input(event: InputEvent) -> void:
    match menu_state:
        "main", "pause":
            var items := menu_items()
            var id: String = items[menu_selection]["id"]
            if event.is_action_pressed("ui_up"):
                menu_selection = (menu_selection + items.size() - 1) % items.size()
                audio.sfx("ui_move", 0.0)
            elif event.is_action_pressed("ui_down"):
                menu_selection = (menu_selection + 1) % items.size()
                audio.sfx("ui_move", 0.0)
            elif id == "language" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
                toggle_language()
                audio.sfx("ui_select", 0.0)
            elif (id == "music" or id == "sfx") and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
                change_volume(id, 0.1 if event.is_action_pressed("ui_right") else -0.1)
            elif event.is_action_pressed("ui_accept"):
                audio.sfx("ui_select", 0.0)
                match id:
                    "continue":
                        resume()
                    "restart":
                        start_fade(new_game)
                    "language":
                        toggle_language()
                    "music", "sfx":
                        change_volume(id, 0.1, true)
                    "controls":
                        controls_return = menu_state
                        menu_state = "controls"
                    "quit":
                        get_tree().quit()
            elif event.is_action_pressed("ui_cancel") and menu_state == "pause":
                resume()
        "shop":
            var rows := _shop_rows()
            if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
                shop_selection = _shop_step(rows, shop_selection, -1 if event.is_action_pressed("ui_up") else 1)
                shop_message = ""
                shop_mood = "idle"
                audio.sfx("ui_move", 0.0)
                audio.speak(_shop_line(rows))
            elif event.is_action_pressed("ui_accept"):
                var row_id: String = rows[shop_selection]["id"]
                if row_id == Shop.NEXT_RUN_ROW:
                    audio.sfx("ui_select", 0.0)
                    start_fade(_begin_next_run)
                else:
                    var coins_before := loadout.coins
                    var equipped_before := loadout.equipped
                    shop_message = Shop.activate(loadout, row_id)
                    shop_mood = "happy" if loadout.coins < coins_before else "idle"  # he likes being paid
                    if loadout.coins < coins_before:
                        audio.sfx("buy", 0.0)
                        audio.sfx("dwarf_laugh", 0.0)
                    elif loadout.equipped != equipped_before:
                        audio.sfx("ui_select", 0.0)
                    else:
                        audio.sfx("no_money", 0.0)
                    audio.speak(shop_message)
                    var after := _shop_rows()
                    if not after[shop_selection]["enabled"]:  # the purchase left too few coins for this row
                        shop_selection = _shop_step(after, shop_selection, 1)
        _:
            if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
                audio.sfx("ui_back", 0.0)
                menu_state = controls_return


# ---------------------------------------------------------------- Matrix Fist

## World speed during the sequence: eases down in 0-1 s, holds, eases back in 3-4 s.
static func fist_time_scale(t: float) -> float:
    if t < 1.0:
        return lerpf(1.0, FIST_SLOW, smoothstep(0.0, 1.0, t))
    if t < FIST_BACK_AT:
        return FIST_SLOW
    if t < FIST_DURATION:
        return lerpf(FIST_SLOW, 1.0, smoothstep(0.0, 1.0, t - FIST_BACK_AT))
    return 1.0


## Press F: spend one charge and start the slow-motion punch. False if it can't start.
func use_fist() -> bool:
    if fist_active or loadout.fists <= 0 or phase != "run" or paused or squirrel.game_over:
        return false
    loadout.fists -= 1
    fist_active = true
    fist_t = 0.0
    fist_x0 = squirrel.x
    fist_dash_started = false
    fist_turned = false
    _fist_end_played = false
    fist_hit.clear()
    audio.sfx("fist_start", 0.0)
    audio.sfx("fist_dash", 0.0)
    return true


func _end_fist() -> void:
    if fist_active and squirrel != null:
        squirrel.x = fist_x0
        squirrel.prev_x = fist_x0
        squirrel.sync()
    fist_active = false
    fist_t = 0.0
    Cfg.time_scale = 1.0


func _update_fist_clock(delta: float) -> void:
    if not fist_active:
        Cfg.time_scale = 1.0
        return
    if fist_t < FIST_BACK_AT and fist_t + delta >= FIST_BACK_AT and not _fist_end_played:
        _fist_end_played = true
        audio.sfx("fist_end", 0.0)  # the world winds back up
    fist_t += delta  # real time: the sequence always lasts 4 s whatever the slow-mo
    if fist_t >= FIST_DURATION:
        _end_fist()
        return
    Cfg.time_scale = fist_time_scale(fist_t)


## True during the dash out and back (0-3 s): invulnerable and intangible.
func _fist_ghosted() -> bool:
    return fist_active and fist_t >= FIST_DASH_AT and fist_t < FIST_BACK_AT


## Move the squirrel along the dash: out across the screen (0-1.5 s) and back
## (1.5-3 s), punching everything on the way. It flies level with the nearest
## target (never above it) and returns to where it was.
func _apply_fist_motion() -> void:
    if not fist_active or squirrel.game_over or fist_t < FIST_DASH_AT:
        return
    if not fist_dash_started:
        fist_dash_started = true
        fist_y0 = squirrel.y
        _choose_dash_height()
    var prev_x := squirrel.x
    if fist_t < FIST_TURN_AT:
        var u := 1.0 - pow(1.0 - (fist_t - FIST_DASH_AT) / FIST_LEG, 3.0)  # fast start, ease out
        squirrel.x = lerpf(fist_x0, fist_x1, u)
        # reach the target height in the first quarter, so the whole run is level
        squirrel.y = lerpf(fist_y0, fist_y1, smoothstep(0.0, 1.0, (fist_t - FIST_DASH_AT) / (FIST_LEG * 0.25)))
        _spawn_ghost()
    elif fist_t < FIST_BACK_AT:
        if not fist_turned:  # turnaround: everything may be hit again on the way back
            fist_turned = true
            fist_hit.clear()
            audio.sfx("fist_turn", 0.0)
            audio.sfx("fist_dash", 0.0, -3.0)
            _spawn_fx(Vector2(squirrel.x + squirrel.w, squirrel.y + squirrel.h / 2.0))
        var u2 := smoothstep(0.0, 1.0, (fist_t - FIST_TURN_AT) / FIST_LEG)
        squirrel.x = lerpf(fist_x1, fist_x0, u2)
        # ...and only come back down/up in the last quarter of the return leg
        squirrel.y = lerpf(fist_y1, fist_y0, smoothstep(0.0, 1.0, ((fist_t - FIST_TURN_AT) / FIST_LEG - 0.75) / 0.25))
        _spawn_ghost()
    else:
        squirrel.x = fist_x0
        squirrel.y = fist_y0
    _fist_strike(prev_x)
    squirrel.velocity_y = 0.0
    squirrel.prev_x = squirrel.x
    squirrel.prev_y = squirrel.y
    squirrel.sync()


## The dash always runs to the far side of the screen; the height follows the
## nearest enemy or tree ahead (ground level, or a flyer's height).
func _choose_dash_height() -> void:
    fist_x1 = maxf(fist_x0 + 40.0, FIST_END_X - squirrel.w)
    fist_y1 = fist_y0
    var best: Entity = null
    var best_left := INF
    var candidates: Array = []
    candidates.append_array(trees)
    for e: Enemy in enemies:
        if e.hittable():
            candidates.append(e)
    for c: Entity in candidates:
        var left := c.rect().position.x
        if c.active and left > squirrel.x + squirrel.w and left < Cfg.SCREEN_W - 10.0 and left < best_left:
            best = c
            best_left = left
    if best == null:
        return
    if best is Enemy and (best as Enemy).air:
        fist_y1 = clampf(best.rect().get_center().y - squirrel.h / 2.0, 40.0, squirrel.ground_y)
    else:
        fist_y1 = squirrel.ground_y


## Punch everything the squirrel swept through since last tick (each thing once
## per leg): enemies take 3 damage (shields don't help), trees are smashed and
## enemy projectiles are destroyed.
func _fist_strike(prev_x: float) -> void:
    var cur_x := squirrel.x
    var going_right := cur_x >= prev_x
    var left := minf(prev_x, cur_x) - (0.0 if going_right else FIST_REACH)
    var width := absf(cur_x - prev_x) + squirrel.w + FIST_REACH
    var sweep := Rect2(left, squirrel.y - FIST_PAD, width, squirrel.h + 2.0 * FIST_PAD)
    for e: Enemy in enemies:
        if e.hittable() and not fist_hit.has(e.get_instance_id()) and e.rect().intersects(sweep):
            fist_hit[e.get_instance_id()] = true
            audio.sfx("fist_hit", 0.08)
            _damage_enemy(e, Weapons.FIST_DAMAGE)
            _spawn_fx(e.rect().get_center())
    for t: TreeProp in trees:
        if t.active and not fist_hit.has(t.get_instance_id()) and t.rect().intersects(sweep):
            fist_hit[t.get_instance_id()] = true
            t.active = false
            loadout.add_coins(TREE_COINS)
            audio.sfx("smash")
            _spawn_fx(t.rect().get_center())
    for es: EnemyShot in enemy_shots:
        if es.active and es.rect().intersects(sweep):
            es.active = false


func _spawn_fx(at: Vector2) -> void:
    var fx := PunchFx.new()
    fx.position = at
    layers["shots"].add_child(fx)
    punch_fx.append(fx)


func _spawn_ghost() -> void:
    _ghost_tick += 1
    if _ghost_tick % 2 != 0:
        return
    var g := Ghost.create(Cfg.tex("squirrel.png"), squirrel.x, squirrel.y, squirrel.w, squirrel.h)
    layers["player"].add_child(g)
    layers["player"].move_child(g, 0)  # behind the squirrel
    ghosts.append(g)


## Fade trails and impact effects in real time (not slow-motion time).
func _tick_fx(real_delta: float) -> void:
    if invuln_timer > 0.0:  # blink while invulnerable after a respawn
        invuln_timer = maxf(0.0, invuln_timer - real_delta)
        squirrel.sprite.modulate.a = 0.35 if int(invuln_timer * 10.0) % 2 == 0 and invuln_timer > 0.0 else 1.0
    elif squirrel.sprite != null:
        squirrel.sprite.modulate.a = 1.0
    for g: Ghost in ghosts.duplicate():
        if not g.tick(real_delta):
            ghosts.erase(g)
            g.queue_free()
    for f: PunchFx in punch_fx.duplicate():
        if not f.tick(real_delta):
            punch_fx.erase(f)
            f.queue_free()


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
    frame(delta)


## Which music should be playing right now ("" = silence).
func _music_track() -> String:
    if phase == "shop":
        return "shop"
    if phase == "run_complete":
        return ""  # the fanfare plays instead
    if squirrel.game_over and loadout.lives <= 0:
        return ""  # game over: the sting, then silence
    if boss_spawned:
        return "boss"
    return "run_a" if run <= 2 else ("run_b" if run <= 5 else "run_c")


func _update_audio() -> void:
    audio.play_music(_music_track())
    audio.set_world_speed(Cfg.time_scale)  # slow motion slows the music too
    audio.set_muffled(paused)


func frame(delta: float) -> void:
    _update_fade(delta)
    flash = maxf(0.0, flash - delta / FLASH_TIME)  # real time, so it is as brief in slow motion
    _update_audio()
    # frozen: paused, between runs, or while the screen is fading in/out
    if paused or phase != "run" or fade_dir != 0:
        if phase == "run_complete" and fade_dir == 0:
            complete_timer += delta
            if complete_timer >= COMPLETE_DELAY:
                start_fade(_enter_shop)
        hud.refresh(_hud_state())
        return

    _update_fist_clock(delta)
    var ts := Cfg.time_scale      # 1 normally, ~0.1 during the Matrix slow-motion
    var gd := delta * ts          # "game time" delta
    var sp := scroll_speed * ts   # scroll this tick
    _tick_fx(delta)

    if not squirrel.game_over:
        scroll_offset += sp
        _spawn_boxes()
        _spawn_trees()
        _spawn_ground_enemies()
        _spawn_birds()
        _spawn_flyers()

    # while dashing the squirrel is a ghost: it passes through boxes, trees and
    # enemies (only the ground and the clouds still hold it)
    var ghosted := _fist_ghosted()
    squirrel.update([] if ghosted else boxes, clouds if ghosted else _platforms())
    _update_ride(ghosted)
    if _was_jumping and not squirrel.is_jumping and not squirrel.game_over:
        audio.sfx("land")
    _was_jumping = squirrel.is_jumping
    _apply_fist_motion()
    if (invuln_timer > 0.0 or armored) and squirrel.game_over:
        squirrel.game_over = false  # blinking after a respawn: boxes can't kill either
    _begin_game_over_if_needed()

    var on_cloud := squirrel.velocity_y >= 0.0 and squirrel.stands_on(clouds)
    if not squirrel.game_over:
        _spawn_rainbow()
        _spawn_life_pickup()
        _spawn_ptero(on_cloud)
        _update_shots()

    # world objects only move while alive; dead ones are still pruned
    var live := not squirrel.game_over
    for t: TreeProp in trees.duplicate():
        if live:
            t.update(sp)
        if not t.active:
            _drop(trees, t)
    for e: Enemy in enemies.duplicate():
        if live:
            var old_x := e.x
            e.update(sp, gd, squirrel.rect())
            if e == ridden:  # the rider goes where the bird goes
                squirrel.x += e.x - old_x
                squirrel.y = e.rect().position.y - squirrel.h
                squirrel.sync()
            var fired := e.take_shot()
            if fired != "":
                _fire_enemy_shot(e, fired)
            var cue := e.take_sound()
            if cue != "" and e.x < Cfg.SCREEN_W:
                audio.sfx(cue)
        if not e.active:
            _drop(enemies, e)
    for es: EnemyShot in enemy_shots.duplicate():
        if live:
            es.update(gd)
        if not es.active:
            if (es.kind == "egg" or es.kind == "nut") and es.y + es.h >= Cfg.SOIL_Y:
                audio.sfx("splat")
            _drop(enemy_shots, es)
    for c: Cloud in clouds.duplicate():
        if live:
            c.update(sp)
        if not c.active:
            _drop(clouds, c)
    for r: RainbowAcorn in rainbows.duplicate():
        if live:
            r.update(sp, gd)
        if not r.active:
            _drop(rainbows, r)
    for lp: LifePickup in life_pickups.duplicate():
        if live:
            lp.update(sp, gd)
        if not lp.active:
            _drop(life_pickups, lp)
    _maintain_clouds()

    if live:
        _check_hazards()
    _update_boxes(live)
    for p: PopupAcorn in popups.duplicate():
        if live:
            p.update(sp, gd)
        if not p.active:
            _drop(popups, p)

    background.set_scroll(scroll_offset)
    if squirrel.game_over:
        over_elapsed += delta
        if loadout.lives > 0 and over_elapsed >= RESPAWN_DELAY:
            _respawn()
    else:
        _advance_run(gd)
    hud.refresh(_hud_state())


## The squirrel just died: lose a life. With lives left it gets back up after a
## moment (see _respawn); with none left the game is over.
func _begin_game_over_if_needed() -> void:
    if squirrel.game_over and not over_started:
        over_started = true
        over_elapsed = 0.0
        _end_fist()
        loadout.lives = maxi(0, loadout.lives - 1)
        if loadout.lives <= 0:
            profile.record_game(score, run)
            audio.sfx("game_over", 0.0)
        else:
            audio.sfx("life_lost")


func _respawn() -> void:
    audio.sfx("respawn")
    squirrel.reset()
    over_started = false
    over_elapsed = 0.0
    invuln_timer = INVULN_TIME
    # clear the way so the squirrel doesn't respawn into the thing that killed it
    for t: TreeProp in trees:
        if t.rect().position.x < 420.0:
            t.active = false
    for e: Enemy in enemies:
        if e.rect().position.x < 420.0 and not e.is_boss:
            e.active = false
    for b: Box in boxes:
        if b.x < 300.0:
            b.active = false
    _clear(enemy_shots)


## The 1UP heart rides in on the top cloud row.
func _spawn_life_pickup() -> void:
    if life_spawned or scroll_offset < next_life:
        return
    var candidates: Array[Cloud] = []
    for c in clouds:
        if c.active and c.y == Cfg.CLOUD_ROWS[0] and c.x >= Cfg.SCREEN_W:
            candidates.append(c)
    if candidates.is_empty():
        return
    var c: Cloud = candidates[randi() % candidates.size()]
    var lp := LifePickup.new()
    lp.place_on(c.x + int(c.w / 2.0) - 17.0, c.y - 40.0)
    layers["rainbow"].add_child(lp)
    life_pickups.append(lp)
    life_spawned = true


## +1 life, or coins when already at the maximum.
func _gain_life() -> void:
    if not loadout.add_life():
        loadout.add_coins(10)


func _hud_state() -> Dictionary:
    var weapon_def: Dictionary = Weapons.DEFS[weapon]
    var dead := phase == "run" and squirrel.game_over and loadout.lives <= 0  # out of lives
    var show_menu := paused or phase == "shop" or (dead and over_elapsed >= MENU_DELAY)
    var banner_text := ""
    var banner_color := Color.RED
    if phase == "run_complete":
        var title := Lang.t("BOSS DEFEATED!") if complete_boss else Lang.t("RUN %d COMPLETE", [run])
        banner_text = "%s\n%s" % [title, Lang.t("+%d coins", [complete_bonus])]
        if complete_life:
            banner_text += "\n" + Lang.t("+1 life")
        banner_color = Color(1.0, 0.85, 0.2)
    elif dead:
        banner_text = Lang.t("GAME OVER")
    elif announce_timer > 0.0:
        banner_text = announce_text
    var boss_alive := boss != null and not boss.defeated and boss.active
    return {
        "score": score, "acorns": acorns, "coins": loadout.coins, "best": profile.best_score,
        "weapon": weapon_def["name"], "weapon_ammo": weapon_def["ammo"], "chestnuts": loadout.stock_left("chestnut"),
        "run": run, "in_run": phase == "run",
        "fists": loadout.fists, "lives": loadout.lives, "armored": armored, "armor_hp": armor_hp,
        "matrix": clampf((1.0 - Cfg.time_scale) / (1.0 - FIST_SLOW), 0.0, 1.0),
        "time_left": maxf(0.0, RUN_SECONDS - run_time), "progress": run_time / RUN_SECONDS,
        "is_boss_run": is_boss_run(run),
        "boss_hp": boss.hp if boss_alive else 0, "boss_max": boss.max_hp if boss != null else 0,
        "banner_text": banner_text, "banner_color": banner_color,
        "show_menu": show_menu, "fade": fade, "flash": flash * FLASH_STRENGTH,
        "menu_state": menu_state, "selection": menu_selection,
        "menu_items": menu_items().map(func(i: Dictionary) -> String: return i["text"]),
        "shop_rows": _shop_rows() if phase == "shop" else [], "shop_selection": shop_selection,
        "shop_message": shop_message, "shop_mood": shop_mood,
    }


# ---------------------------------------------------------------- spawning

func _spawn_cloud(px: float, py: float) -> Cloud:
    var c := Cloud.new()
    c.setup(px, py)
    layers["clouds"].add_child(c)
    clouds.append(c)
    return c


## Keep both cloud rows full to the right of the screen.
func _maintain_clouds() -> void:
    for row_y: float in Cfg.CLOUD_ROWS:
        var rightmost := -1.0
        for c in clouds:
            if c.y == row_y and c.active:
                rightmost = maxf(rightmost, c.x + c.w)
        if rightmost < Cfg.SCREEN_W + 100:
            _spawn_cloud(rightmost + Cfg.CLOUD_SPACING, row_y)


## y range (top of a 40px thing) that the squirrel can bump from the ground
## with a full jump but not walk into. Used for boxes and birds.
func _reachable_y(thing_h: float) -> int:
    var ground := Cfg.SOIL_Y - squirrel.h
    var lo := ground - Cfg.MAX_JUMP_HEIGHT - thing_h
    var hi := ground - thing_h - 1.0
    return randi_range(int(lo), int(hi))


func _spawn_boxes() -> void:
    if scroll_offset < next_box:
        return
    var min_gap := 4.0 * 40.0 / scroll_speed  # keep clear of the last tree
    if scroll_offset - last_tree_spawn < min_gap:
        next_box = last_tree_spawn + min_gap
        return
    var b := Box.new()
    b.place(Cfg.SPAWN_X, _reachable_y(40.0))
    layers["boxes"].add_child(b)
    boxes.append(b)
    last_box_spawn = scroll_offset
    next_box = scroll_offset + randi_range(BOX_SPAWN_DISTANCE, BOX_SPAWN_DISTANCE + 400)


func _spawn_trees() -> void:
    if scroll_offset < next_tree:
        return
    var min_gap := 2.0 * 60.0 / scroll_speed  # keep clear of the last box
    if scroll_offset - last_box_spawn < min_gap:
        next_tree = last_box_spawn + min_gap
        return
    var t := TreeProp.new()
    t.place(Cfg.SPAWN_X, Cfg.SOIL_Y - t.h)
    layers["trees"].add_child(t)
    trees.append(t)
    last_tree_spawn = scroll_offset
    next_tree = scroll_offset + randi_range(TREE_SPAWN_DISTANCE, TREE_SPAWN_DISTANCE + 800)


func _spawn_enemy(kind: String, py: float = -1.0) -> Enemy:
    var e := Enemy.create(kind, Cfg.SPAWN_X, 0.0)
    e.y = py if py >= 0.0 else Cfg.SOIL_Y - e.h  # default: standing on the soil
    e.anchor()
    e.scale_for_run(run)
    e.sync()
    layers["air" if e.air else "ground"].add_child(e)
    enemies.append(e)
    return e


## Random spawn gap, shrinking as the runs get harder.
func _gap(base: int, extra: int) -> float:
    return randi_range(base, base + extra) * gap_factor


func _spawn_ground_enemies() -> void:
    if boss_spawned:
        return  # the boss fights alone
    if scroll_offset >= next_skunk:
        _spawn_enemy("skunk")
        next_skunk = scroll_offset + _gap(SKUNK_SPAWN_DISTANCE, 1000)
    if run >= BEAVER_FROM_RUN and scroll_offset >= next_beaver:
        _spawn_enemy("beaver")
        next_beaver = scroll_offset + _gap(BEAVER_SPAWN_DISTANCE, 1000)
    if run >= CROCO_FROM_RUN and scroll_offset >= next_croco:
        _spawn_enemy("croco")
        next_croco = scroll_offset + _gap(CROCO_SPAWN_DISTANCE, 1000)
    if run >= RACCOON_FROM_RUN and scroll_offset >= next_raccoon:
        next_raccoon = scroll_offset + _gap(RACCOON_SPAWN_DISTANCE, 1200)
        if Enemy.is_available("raccoon"):
            _spawn_enemy("raccoon")
    if run >= MOLE_FROM_RUN and scroll_offset >= next_mole:
        _spawn_enemy("mole")
        next_mole = scroll_offset + _gap(MOLE_SPAWN_DISTANCE, 1000)


func _spawn_birds() -> void:
    if boss_spawned or scroll_offset < next_bird:
        return
    _spawn_enemy("bird", _reachable_y(40.0))
    next_bird = scroll_offset + _gap(BIRD_SPAWN_DISTANCE, 600)


## Later runs add airborne newcomers: bee swarms (run 2+) and owls (run 7+).
func _spawn_flyers() -> void:
    if boss_spawned:
        return
    if run >= BEE_FROM_RUN and scroll_offset >= next_bee and Enemy.is_available("bee"):
        next_bee = scroll_offset + _gap(BEE_SPAWN_DISTANCE, 800)
        var y := float(_reachable_y(32.0))
        for i in 3:  # a staggered swarm, each bee zigzagging out of phase
            var bee := _spawn_enemy("bee", y)
            bee.x += i * 55.0
            bee.life = i * 0.9
    if run >= OWL_FROM_RUN and scroll_offset >= next_owl:
        next_owl = scroll_offset + _gap(OWL_SPAWN_DISTANCE, 1200)
        if Enemy.is_available("owl"):
            _spawn_enemy("owl", 270.0)


## 1-in-30 chance per tick, one at a time, riding in on an off-screen cloud of the lower cloud row.
func _spawn_rainbow() -> void:
    for r in rainbows:
        if r.active and not r.collected:
            return
    if randi_range(1, 30) != 1:
        return
    var candidates: Array[Cloud] = []
    for c in clouds:
        if c.active and c.y == 250.0 and c.x >= Cfg.SCREEN_W:
            candidates.append(c)
    if candidates.is_empty():
        return
    var c: Cloud = candidates[randi() % candidates.size()]
    var r := RainbowAcorn.new()
    r.place(c.x + int(c.w / 2.0) - 15.0, c.y - 30.0)
    layers["rainbow"].add_child(r)
    rainbows.append(r)


## Pterodactyls only hunt a squirrel that is standing on a cloud.
func _spawn_ptero(on_cloud: bool) -> void:
    if boss_spawned or not on_cloud or scroll_offset < next_ptero:
        return
    next_ptero = scroll_offset + _gap(PTERO_SPAWN_DISTANCE, 600)
    _spawn_enemy("ptero", 100.0)


# ---------------------------------------------------------------- collisions

func _update_shots() -> void:
    for sh: Shot in shots.duplicate():
        sh.update(squirrel, enemies)
        if sh.bounced:
            sh.bounced = false
            audio.sfx("land", 0.1, -3.0)  # the chestnut hits the ground
        if sh.active and not sh.exploding:
            _shot_hits_enemies(sh)
        if sh.active and not sh.exploding:
            _shot_hits_enemy_shots(sh)
        if sh.exploding and not sh.exploded:
            sh.exploded = true
            _blast(sh)
        if not sh.active:
            _drop(shots, sh)


func _shot_hits_enemies(sh: Shot) -> void:
    var sr := sh.rect()
    for e: Enemy in enemies:
        if not e.hittable() or not e.rect().intersects(sr):
            continue
        if e.blocks(sh) and sh.blast_radius <= 0.0:  # the shield stops it (explosives still blast)
            e.shield_flash = 0.15
            audio.sfx("shield_clang")
            if sh.kind == "boomerang":  # bounces off and flies back
                sh.returning = true
                sh.vx = -absf(sh.vx)
                sh.hit_ids.clear()
                sh.hit_ids[e.get_instance_id()] = true
            else:
                sh.active = false
            return
        if sh.pierce:
            var id := e.get_instance_id()
            if sh.hit_ids.has(id):
                continue
            sh.hit_ids[id] = true
            _damage_enemy(e, sh.damage)
        elif sh.blast_radius > 0.0:
            sh.detonate()  # explosives (pinecone, chestnut): damage is dealt by _blast
            return
        else:
            sh.active = false
            _damage_enemy(e, sh.damage)
            return


## Acorns (and every other weapon) shoot down enemy projectiles.
func _shot_hits_enemy_shots(sh: Shot) -> void:
    var sr := sh.rect()
    for es: EnemyShot in enemy_shots:
        if es.active and es.rect().intersects(sr):
            es.active = false
            if not sh.pierce:
                if sh.blast_radius > 0.0:
                    sh.detonate()
                else:
                    sh.active = false
                return


func _fire_enemy_shot(e: Enemy, kind: String) -> void:
    var r := e.rect()
    var es: EnemyShot
    match kind:
        "gas":
            es = EnemyShot.create("gas", r.position.x - 6.0, Cfg.SOIL_Y - 22.0)
        "egg":
            es = EnemyShot.create("egg", r.get_center().x, r.end.y)
        "nut":  # leaves his front paws (the side he faces) and flies straight and level
            es = EnemyShot.create("nut", r.position.x - 12.0, r.position.y + r.size.y * 0.45)
        _:  # "fire": aimed at the squirrel
            var from := Vector2(r.position.x, r.get_center().y)
            es = EnemyShot.create("fire", from.x, from.y, (squirrel.rect().get_center() - from).normalized())
    layers["shots"].add_child(es)
    enemy_shots.append(es)
    match kind:
        "gas":
            audio.sfx("hiss")
        "fire":
            audio.sfx("fireball")


func _blast(sh: Shot) -> void:
    audio.sfx("boom")
    flash = 1.0  # every explosion starts with a white flash of the whole screen
    var c := sh.blast_center()
    for e: Enemy in enemies:
        if e.hittable() and e.rect().get_center().distance_to(c) <= sh.blast_radius + minf(e.w, e.h) / 2.0:
            _damage_enemy(e, sh.damage)


## Apply a hit; a defeated enemy pays score and coins.
func _damage_enemy(e: Enemy, dmg: int) -> void:
    if e.hit(dmg):
        score += 10 if e.is_boss else 1
        loadout.add_coins(e.cfg["coins"])
        audio.sfx("enemy_defeat")
        audio.sfx("coin", 0.1, -2.0)
    else:
        audio.sfx("hit")


## The squirrel was touched by something dangerous. In the Diver Armor that costs one health
## point (and the armor breaks at 0); otherwise it is lethal.
func _hurt() -> void:
    if not armored:
        squirrel.game_over = true
        return
    armor_hp = maxi(0, armor_hp - 1)
    squirrel.armor_frac = float(armor_hp) / Weapons.ARMOR_HP
    squirrel.flash_hurt()
    audio.sfx("hit")
    if armor_hp <= 0:
        _break_armor()


## 0 health points: the armor falls off and the run goes on as the plain squirrel (no life is lost).
func _break_armor() -> void:
    armored = false
    armor_hp = 0
    squirrel.set_diver(false)
    weapon = loadout.equipped
    invuln_timer = ARMOR_BREAK_GRACE  # blinks for a moment, like after a respawn
    announce_text = Lang.t("ARMOR BROKEN!")
    announce_timer = ANNOUNCE_TIME
    audio.sfx("life_lost")


## An enemy/tree is only lethal when it reaches the squirrel's front (left side
## of the obstacle) - you can jump over or walk through the rest of it.
func _crossed(prev_left: float, left: float) -> bool:
    var front := squirrel.x + squirrel.w
    return prev_left >= front and left <= front


func _check_hazards() -> void:
    var sr := squirrel.rect()
    if not _fist_ghosted() and invuln_timer <= 0.0:  # a dashing ghost / a blinking respawn can't be hurt
        for t in trees:
            if t.active and t.rect().intersects(sr) and _crossed(t.prev_x + t.hit_dx(), t.x + t.hit_dx()):
                _hurt()
        for e in enemies:  # (the boss too: its charge crosses the squirrel like any enemy)
            if e.hittable() and e.rect().intersects(sr) and _crossed(e.prev_x + e.hit_dx(), e.x + e.hit_dx()):
                _hurt()
        for es in enemy_shots:  # projectiles hurt on any contact
            if es.active and es.rect().intersects(sr) and not es.hurt_player:
                es.hurt_player = true  # (a lingering gas cloud costs one point, not one per tick)
                _hurt()
    _begin_game_over_if_needed()

    for r in rainbows:
        if r.active and not r.collected and r.rect().intersects(sr):
            r.collect()
            audio.sfx("rainbow_collect")
            acorns += 5
            score += 2
            loadout.add_coins(RAINBOW_COINS)
            break

    for lp in life_pickups:
        if lp.active and lp.rect().intersects(sr):
            lp.active = false
            audio.sfx("oneup")
            _gain_life()
            var fx := PunchFx.new()
            fx.position = lp.rect().get_center()
            layers["shots"].add_child(fx)
            punch_fx.append(fx)


func _update_boxes(live: bool) -> void:
    var sr := squirrel.rect()
    for b: Box in boxes.duplicate():
        if live:
            b.update(scroll_speed * Cfg.time_scale)
        if not b.active:
            _drop(boxes, b)
        elif not b.collected:
            if b.should_collect:
                b.should_collect = false
                b.mark_collected()
                audio.sfx("box_bump")
                audio.sfx("coin", 0.1, -1.0)
                var gained := randi_range(1, 3)
                acorns += gained
                loadout.add_coins(BOX_COINS)
                for i in gained:
                    var p := PopupAcorn.new()
                    p.start(b.x, b.y, b.w, (i - (gained - 1) / 2.0) * 25.0)
                    layers["popups"].add_child(p)
                    popups.append(p)
            elif b.rect().intersects(sr):
                b.should_collect = false
