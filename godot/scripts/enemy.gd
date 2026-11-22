class_name Enemy
extends Entity
## One data-driven class for every opponent. Add a new enemy by adding an entry
## to KINDS (size, sprite frames, speed, hp) - no new class or copy-pasted code.
##
## Behaviour shared by all kinds:
##  - scrolls with the world, plus an optional extra `forward` speed
##  - hit by an acorn: loses 1 hp; at 0 hp it is `defeated` and plays the
##    "hop then fall off screen" animation
##  - lethal to the squirrel only on a left-side hit (see Game._crossed)
## Mole is special: it cycles between underground (harmless) and surfaced.

const KINDS := {
    "skunk": {
        "w": 80.0, "h": 80.0, "air": false, "hp": 1,
        "frames": ["skunk_1.png", "skunk_2.png", "skunk_3.png"],
        "interval": 1.5, "random_frames": true, "forward": 0.0, "fall_vx": -2.5,
    },
    "beaver": {
        "w": 90.0, "h": 40.0, "air": false, "hp": 2,
        "frames": ["beaver1.png", "beaver2.png", "beaver3.png"],
        "interval": 0.25, "random_frames": false, "forward": -2.0, "fall_vx": -2.5,
    },
    # Implemented in the pygame version but never spawned there either.
    "croco": {
        "w": 80.0, "h": 80.0, "air": false, "hp": 2,
        "frames": ["croco1.png", "croco2.png", "croco3.png"],
        "interval": 0.75, "random_frames": true, "forward": -2.0, "fall_vx": -2.5,
    },
    "mole": {
        "w": 60.0, "h": 60.0, "air": false, "hp": 1,
        "frames": ["mole1.png", "mole2.png"],  # 0 = underground, 1 = surfaced
        "interval": 0.0, "random_frames": false, "forward": 0.0, "fall_vx": -2.5,
    },
    "bird": {
        "w": 60.0, "h": 60.0, "air": true, "hp": 1,
        "frames": ["bird_1.png", "bird_2.png"],
        "interval": 0.5, "random_frames": false, "forward": -0.5, "fall_vx": -2.5,
    },
    "ptero": {
        "w": 90.0, "h": 60.0, "air": true, "hp": 2,
        "frames": ["ptero1.png", "ptero2.png"],
        "interval": 1.0, "random_frames": false, "forward": -1.0, "fall_vx": -3.0,
    },
}

const DEFEAT_HOP_HEIGHT := 20.0

var kind := ""
var cfg: Dictionary
var hp := 1
var defeated := false
var air := false
var prev_x := 0.0

var frame_idx := 0
var anim_timer := 0.0

var underground := false  # mole only
var mole_timer := 0.0
var mole_interval := 0.0

var fall_started := false
var fall_vy := 0.0


static func create(enemy_kind: String, px: float, py: float) -> Enemy:
    var e := Enemy.new()
    e.setup(enemy_kind, px, py)
    return e


func setup(enemy_kind: String, px: float, py: float) -> void:
    kind = enemy_kind
    cfg = KINDS[kind]
    w = cfg["w"]
    h = cfg["h"]
    hp = cfg["hp"]
    air = cfg["air"]
    place(px, py)
    prev_x = x
    if kind == "mole":
        underground = true
        mole_interval = randf_range(3.0, 5.0)
    _show_frame(0)


func _show_frame(i: int) -> void:
    frame_idx = i
    set_sprite(Cfg.tex(cfg["frames"][i]))


## Can an acorn hurt it / can it hurt the squirrel right now?
func hittable() -> bool:
    if not active or defeated:
        return false
    return not (kind == "mole" and underground)


func hit() -> bool:
    ## Apply one acorn hit. Returns true if this hit defeated it.
    hp -= 1
    if hp <= 0:
        defeated = true
        return true
    return false


func update(scroll_speed: float, delta: float) -> void:
    if defeated:
        _update_defeated(scroll_speed)
    elif kind == "mole":
        _update_mole(scroll_speed, delta)
    else:
        _update_walker(scroll_speed, delta)
    sync()


func _update_walker(scroll_speed: float, delta: float) -> void:
    prev_x = x
    x -= scroll_speed
    x += cfg["forward"]
    anim_timer += delta
    if anim_timer >= cfg["interval"]:
        anim_timer = 0.0
        var n: int = cfg["frames"].size()
        _show_frame(randi() % n if cfg["random_frames"] else (frame_idx + 1) % n)
    if x + w < 0.0:
        active = false


func _update_mole(scroll_speed: float, delta: float) -> void:
    prev_x = x
    x -= scroll_speed
    mole_timer += delta
    if mole_timer >= mole_interval:
        underground = not underground
        mole_timer = 0.0
        mole_interval = randf_range(3.0, 7.0)
        _show_frame(0 if underground else 1)
    if x + w < 0.0:
        active = false


func _update_defeated(scroll_speed: float) -> void:
    if not fall_started:
        fall_started = true
        fall_vy = -sqrt(2.0 * Cfg.GRAVITY * DEFEAT_HOP_HEIGHT)  # hop up first
        if kind == "mole":
            underground = false
            _show_frame(1)
    fall_vy += Cfg.GRAVITY
    y += fall_vy
    x += cfg["fall_vx"]
    if kind == "mole":
        x -= scroll_speed  # a defeated mole is still carried by the ground
    if x + w < 0.0 or y > Cfg.SCREEN_H:
        active = false
