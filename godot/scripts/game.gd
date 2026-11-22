extends Node2D
## Main game: owns the world state, spawner, collisions and game-over flow.
## One fixed 60 Hz `frame()` per physics tick, in the same order as the
## original pygame main loop so the feel is identical.

const MENU_DELAY := 3.0  # seconds of "GAME OVER" before the menu appears

# spawn gaps in scroll-offset units (base .. base + extra)
const BOX_SPAWN_DISTANCE := 1200
const TREE_SPAWN_DISTANCE := 1500
const SKUNK_SPAWN_DISTANCE := 2000
const BEAVER_SPAWN_DISTANCE := 1700
const MOLE_SPAWN_DISTANCE := 1800
const BIRD_SPAWN_DISTANCE := 1500
const PTERO_SPAWN_DISTANCE := 2000
# score gates: skunks until BEAVER_SCORE, then beavers; moles from MOLE_SCORE
const BEAVER_SCORE := 10
const MOLE_SCORE := 15

const LAYERS := ["trees", "ground", "air", "clouds", "rainbow", "boxes", "popups", "player", "shots"]

# --- run state ---
var acorns := 3
var score := 0
var scroll_offset := 0.0

var next_box := 200.0
var next_tree := 500.0
var next_skunk := 1000.0
var next_beaver := 1000.0
var next_mole := 1200.0
var next_bird := 800.0
var next_ptero := 1500.0
var last_box_spawn := -INF
var last_tree_spawn := -INF

var over_started := false
var over_elapsed := 0.0
var menu_state := "main"  # "main" | "controls"
var menu_selection := 0

# --- world ---
var squirrel: Squirrel
var background: Background
var hud: Hud
var layers := {}

var shots: Array[Acorn] = []
var boxes: Array[Box] = []
var trees: Array[TreeProp] = []
var enemies: Array[Enemy] = []
var popups: Array[PopupAcorn] = []
var clouds: Array[Cloud] = []
var rainbows: Array[RainbowAcorn] = []


func _ready() -> void:
    randomize()
    _setup_input()

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

    reset_game()


func _setup_input() -> void:
    _add_key_action("jump", KEY_SPACE)
    _add_key_action("throw", KEY_SHIFT)


func _add_key_action(action: String, keycode: Key) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode
    InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- state

func reset_game() -> void:
    scroll_offset = 0.0
    acorns = 3
    score = 0
    next_box = 200.0
    next_tree = 500.0
    next_skunk = 1000.0
    next_beaver = 1000.0
    next_mole = 1200.0
    next_bird = 800.0
    next_ptero = 1500.0
    last_box_spawn = -INF
    last_tree_spawn = -INF
    over_started = false
    over_elapsed = 0.0
    menu_state = "main"
    menu_selection = 0

    _clear(shots)
    _clear(boxes)
    _clear(trees)
    _clear(enemies)
    _clear(popups)
    _clear(clouds)
    _clear(rainbows)

    for row_y: float in Cfg.CLOUD_ROWS:
        var cx := 0.0
        while cx < Cfg.SCREEN_W + 200:
            var c := _spawn_cloud(cx, row_y)
            cx += c.w + Cfg.CLOUD_SPACING

    squirrel.reset()
    background.set_scroll(0.0)


func _clear(list: Array) -> void:
    for item: Node in list:
        item.queue_free()
    list.clear()


func _drop(list: Array, item: Node) -> void:
    list.erase(item)
    item.queue_free()


# ---------------------------------------------------------------- input

func do_jump() -> void:
    squirrel.jump(boxes, clouds)


func do_throw() -> void:
    if acorns <= 0:
        return
    var a := Acorn.new()
    a.place(squirrel.x + squirrel.w, squirrel.y + int(squirrel.h / 2.0))
    layers["shots"].add_child(a)
    shots.append(a)
    acorns -= 1


func _input(event: InputEvent) -> void:
    if event is InputEventKey and (event.is_echo() or not event.is_pressed()):
        return
    if squirrel.game_over:
        if over_elapsed >= MENU_DELAY:
            _menu_input(event)
        return
    if event.is_action_pressed("jump"):
        do_jump()
    elif event.is_action_pressed("throw"):
        do_throw()


func _menu_input(event: InputEvent) -> void:
    if menu_state == "main":
        if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
            menu_selection = (menu_selection + 1) % 2
        elif event.is_action_pressed("ui_accept"):
            if menu_selection == 0:
                reset_game()
            else:
                menu_state = "controls"
    elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
        menu_state = "main"


# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
    frame(delta)


func frame(delta: float) -> void:
    if not squirrel.game_over:
        scroll_offset += Cfg.SCROLL_SPEED
        _spawn_boxes()
        _spawn_trees()
        _spawn_ground_enemies()
        _spawn_birds()

    squirrel.update(boxes, clouds)
    if squirrel.game_over and not over_started:
        over_started = true
        over_elapsed = 0.0

    var on_cloud := squirrel.velocity_y >= 0.0 and squirrel.stands_on(clouds)
    if not squirrel.game_over:
        _spawn_rainbow()
        _spawn_ptero(on_cloud)
        _update_shots()

    # world objects only move while alive; dead ones are still pruned
    var live := not squirrel.game_over
    for t: TreeProp in trees.duplicate():
        if live:
            t.update(Cfg.SCROLL_SPEED)
        if not t.active:
            _drop(trees, t)
    for e: Enemy in enemies.duplicate():
        if live:
            e.update(Cfg.SCROLL_SPEED, delta)
        if not e.active:
            _drop(enemies, e)
    for c: Cloud in clouds.duplicate():
        if live:
            c.update(Cfg.SCROLL_SPEED)
        if not c.active:
            _drop(clouds, c)
    for r: RainbowAcorn in rainbows.duplicate():
        if live:
            r.update(Cfg.SCROLL_SPEED, delta)
        if not r.active:
            _drop(rainbows, r)
    _maintain_clouds()

    if live:
        _check_hazards()
    _update_boxes(live)
    for p: PopupAcorn in popups.duplicate():
        if live:
            p.update(Cfg.SCROLL_SPEED, delta)
        if not p.active:
            _drop(popups, p)

    background.set_scroll(scroll_offset)
    if squirrel.game_over:
        over_elapsed += delta
    hud.refresh(score, acorns, squirrel.game_over, squirrel.game_over and over_elapsed >= MENU_DELAY, menu_state, menu_selection)


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
    var min_gap := 4.0 * 40.0 / Cfg.SCROLL_SPEED  # keep clear of the last tree
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
    var min_gap := 2.0 * 60.0 / Cfg.SCROLL_SPEED  # keep clear of the last box
    if scroll_offset - last_box_spawn < min_gap:
        next_tree = last_box_spawn + min_gap
        return
    var t := TreeProp.new()
    t.place(Cfg.SPAWN_X, Cfg.SOIL_Y - t.h)
    layers["trees"].add_child(t)
    trees.append(t)
    last_tree_spawn = scroll_offset
    next_tree = scroll_offset + randi_range(TREE_SPAWN_DISTANCE, TREE_SPAWN_DISTANCE + 800)


func _spawn_enemy(kind: String, py: float = -1.0) -> void:
    var e := Enemy.create(kind, Cfg.SPAWN_X, 0.0)
    e.y = py if py >= 0.0 else Cfg.SOIL_Y - e.h  # default: standing on the soil
    e.sync()
    layers["air" if e.air else "ground"].add_child(e)
    enemies.append(e)


func _spawn_ground_enemies() -> void:
    if score < BEAVER_SCORE:
        if scroll_offset >= next_skunk:
            _spawn_enemy("skunk")
            next_skunk = scroll_offset + randi_range(SKUNK_SPAWN_DISTANCE, SKUNK_SPAWN_DISTANCE + 1000)
    elif scroll_offset >= next_beaver:
        _spawn_enemy("beaver")
        next_beaver = scroll_offset + randi_range(BEAVER_SPAWN_DISTANCE, BEAVER_SPAWN_DISTANCE + 1000)
    if score >= MOLE_SCORE and scroll_offset >= next_mole:
        _spawn_enemy("mole")
        next_mole = scroll_offset + randi_range(MOLE_SPAWN_DISTANCE, MOLE_SPAWN_DISTANCE + 1000)


func _spawn_birds() -> void:
    if scroll_offset < next_bird:
        return
    _spawn_enemy("bird", _reachable_y(40.0))
    next_bird = scroll_offset + randi_range(BIRD_SPAWN_DISTANCE, BIRD_SPAWN_DISTANCE + 600)


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
    if not on_cloud or scroll_offset < next_ptero:
        return
    next_ptero = scroll_offset + randi_range(PTERO_SPAWN_DISTANCE, PTERO_SPAWN_DISTANCE + 600)
    _spawn_enemy("ptero", 100.0)


# ---------------------------------------------------------------- collisions

func _update_shots() -> void:
    for a: Acorn in shots.duplicate():
        a.update()
        var ar := a.rect()
        for e in enemies:
            if e.hittable() and e.rect().intersects(ar):
                a.active = false
                if e.hit():
                    score += 1
                break
        if not a.active:
            _drop(shots, a)


## An enemy/tree is only lethal when it reaches the squirrel's front (left side
## of the obstacle) - you can jump over or walk through the rest of it.
func _crossed(prev_left: float, left: float) -> bool:
    var front := squirrel.x + squirrel.w
    return prev_left >= front and left <= front


func _check_hazards() -> void:
    var sr := squirrel.rect()
    for t in trees:
        if t.active and t.rect().intersects(sr) and _crossed(t.prev_x, t.x):
            squirrel.game_over = true
    for e in enemies:
        if e.hittable() and e.rect().intersects(sr) and _crossed(e.prev_x, e.x):
            squirrel.game_over = true
    if squirrel.game_over and not over_started:
        over_started = true
        over_elapsed = 0.0

    for r in rainbows:
        if r.active and not r.collected and r.rect().intersects(sr):
            r.collect()
            acorns += 5
            score += 2
            break


func _update_boxes(live: bool) -> void:
    var sr := squirrel.rect()
    for b: Box in boxes.duplicate():
        if live:
            b.update(Cfg.SCROLL_SPEED)
        if not b.active:
            _drop(boxes, b)
        elif not b.collected:
            if b.should_collect:
                b.should_collect = false
                b.mark_collected()
                var gained := randi_range(1, 3)
                acorns += gained
                for i in gained:
                    var p := PopupAcorn.new()
                    p.start(b.x, b.y, b.w, (i - (gained - 1) / 2.0) * 25.0)
                    layers["popups"].add_child(p)
                    popups.append(p)
            elif b.rect().intersects(sr):
                b.should_collect = false
