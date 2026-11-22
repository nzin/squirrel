class_name Enemy
extends Entity
## One data-driven class for every opponent. Add a new enemy by adding an entry
## to KINDS (size, sprite frames, speed, hp, "ai", "shoot"...) - no new class.
##
## Shared behaviour:
##  - scrolls with the world, plus an optional extra `forward` speed
##  - hit by a shot: loses `damage` hp (pays `coins` when defeated); at 0 hp it
##    is `defeated` and plays the "hop then fall off screen" animation
##  - lethal to the squirrel only on a left-side hit (see Game._crossed)
## Movement ("ai" in KINDS):
##    wave    sine-wave flight (bird)
##    dive    cruises, blinks, then dives at where the squirrel stood (ptero)
##    charge  walks, blinks, then dashes (beaver)
##    hop     leaps in short jumps (croco)
##    burrow  mole: tunnels toward the squirrel and surfaces just ahead of it
##    roll    hedgehog: curls into a spiky ball and rolls at you - acorns bounce off
##    pounce  fox: runs fast, crouches, then leaps at you
## (owl and bee use `wave` with their own "wave_amp" / "wave_freq": a slow wide
## swoop and a fast jittery zigzag)
## Protection: `shielded` blocks shots from the front (not rainbow, bombs, or a
## returning boomerang); extra hp from armor in later runs; `enraged` below
## half hp (faster, from run 4 only). Shooting ("shoot": gas / egg / fire) only from `shoot_from`.
## All movement is multiplied by Cfg.time_scale so slow motion stays smooth.

const KINDS := {
    "skunk": {
        "hit": Rect2(0.04, 0.53, 0.84, 0.47), "coins": 3,
        "w": 80.0, "h": 80.0, "air": false, "hp": 1,
        "frames": ["skunk_1.png", "skunk_2.png", "skunk_3.png"],
        "interval": 1.5, "random_frames": true, "forward": 0.0, "fall_vx": -2.5,
        "shoot": "gas", "shoot_from": 3,
    },
    "beaver": {
        "hit": Rect2(0.06, 0.14, 0.91, 0.84), "coins": 5,
        "w": 90.0, "h": 40.0, "air": false, "hp": 2,
        "frames": ["beaver1.png", "beaver2.png", "beaver3.png"],
        "interval": 0.25, "random_frames": false, "forward": -2.0, "fall_vx": -2.5,
        "ai": "charge", "can_shield": true,
    },
    "croco": {
        "hit": Rect2(0.07, 0.42, 0.86, 0.57), "coins": 6,
        "w": 80.0, "h": 80.0, "air": false, "hp": 2,
        "frames": ["croco1.png", "croco2.png", "croco3.png"],
        "interval": 0.75, "random_frames": true, "forward": -1.0, "fall_vx": -2.5,
        "ai": "hop", "can_shield": true,
    },
    "mole": {
        "hit": Rect2(0.10, 0.34, 0.84, 0.66), "coins": 5,
        "w": 60.0, "h": 60.0, "air": false, "hp": 1,
        "frames": ["mole1.png", "mole2.png"],  # 0 = underground, 1 = surfaced
        "interval": 0.0, "random_frames": false, "forward": 0.0, "fall_vx": -2.5,
        "ai": "burrow",
    },
    "bird": {
        "hit": Rect2(0.07, 0.25, 0.73, 0.53), "coins": 3,
        "w": 60.0, "h": 60.0, "air": true, "hp": 1,
        "frames": ["bird_1.png", "bird_2.png"],
        "interval": 0.5, "random_frames": false, "forward": -0.5, "fall_vx": -2.5,
        "ai": "wave", "shoot": "egg", "shoot_from": 4,
    },
    "ptero": {
        "hit": Rect2(0.19, 0.18, 0.55, 0.54), "coins": 8,
        "w": 90.0, "h": 60.0, "air": true, "hp": 2,
        "frames": ["ptero1.png", "ptero2.png"],
        "interval": 1.0, "random_frames": false, "forward": -1.0, "fall_vx": -3.0,
        "ai": "dive", "shoot": "fire", "shoot_from": 5,
    },
    "hedgehog": {
        "hit": Rect2(0.09, 0.15, 0.83, 0.78), "coins": 7,
        "w": 70.0, "h": 50.0, "air": false, "hp": 2,
        "frames": ["hedgehog1.png", "hedgehog2.png", "hedgehog_ball.png"], "anim_frames": 2,  # last = curled up
        "interval": 0.25, "random_frames": false, "forward": -0.5, "fall_vx": -2.5,
        "ai": "roll",
    },
    "fox": {
        "hit": Rect2(0.17, 0.24, 0.75, 0.62), "coins": 7,
        "w": 90.0, "h": 56.0, "air": false, "hp": 2,
        "frames": ["fox1.png", "fox2.png"],
        "interval": 0.18, "random_frames": false, "forward": -2.8, "fall_vx": -2.5,
        "ai": "pounce", "can_shield": true,
    },
    "owl": {
        "hit": Rect2(0.09, 0.12, 0.83, 0.85), "coins": 8,
        "w": 70.0, "h": 76.0, "air": true, "hp": 2,
        "frames": ["owl1.png", "owl2.png"],
        "interval": 0.4, "random_frames": false, "forward": -1.0, "fall_vx": -2.5,
        "ai": "wave", "wave_amp": 105.0, "wave_freq": 1.5, "can_shield": true,
    },
    "bee": {
        "hit": Rect2(0.11, 0.31, 0.76, 0.54), "coins": 2,
        "w": 40.0, "h": 32.0, "air": true, "hp": 1,
        "frames": ["bee1.png", "bee2.png"],
        "interval": 0.08, "random_frames": false, "forward": -1.6, "fall_vx": -2.5,
        "ai": "wave", "wave_amp": 50.0, "wave_freq": 7.0,
    },
    # Bosses: big versions of ordinary sprites. They walk in, stand and spit
    # fire, then blink red and charge across the screen - jump over (or onto) them.
    "boss_beaver": {
        "hit": Rect2(0.06, 0.14, 0.91, 0.84), "coins": 40, "boss": true,
        "w": 230.0, "h": 102.0, "air": false, "hp": 10,
        "frames": ["beaver1.png", "beaver2.png", "beaver3.png"],
        "interval": 0.2, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
    },
    "boss_croco": {
        "hit": Rect2(0.07, 0.42, 0.86, 0.57), "coins": 60, "boss": true,
        "w": 230.0, "h": 136.0, "air": false, "hp": 14,
        "frames": ["croco1.png", "croco2.png", "croco3.png"],
        "interval": 0.5, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
    },
    "boss_skunk": {
        "hit": Rect2(0.04, 0.53, 0.84, 0.47), "coins": 80, "boss": true,
        "w": 210.0, "h": 166.0, "air": false, "hp": 18,
        "frames": ["skunk_1.png", "skunk_2.png", "skunk_3.png"],
        "interval": 0.6, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
    },
}

const DEFEAT_HOP_HEIGHT := 20.0

# One boss every 3rd run, cycling through BOSSES.
const BOSSES: Array[String] = ["boss_beaver", "boss_croco", "boss_skunk"]
const BOSS_STOP_MARGIN := 40.0
const BOSS_IDLE_TIME := 2.0
const BOSS_WARN_TIME := 0.8
const BOSS_CHARGE_SPEED := 7.0

const ENRAGE_FROM_RUN := 4   # no angry enemies in the first runs
const SHIELD_FROM_RUN := 7   # no protected (shielded) enemies before this run
const TELEGRAPH := 0.45        # warning blink before a shot / charge / dive
const CHARGE_TRIGGER := 330.0  # beaver charges when this close
const CHARGE_SPEED := 6.0
const DIVE_TRIGGER := 360.0
const DIVE_SPEED := 7.5
const HOP_SPEED := -11.5
const HOP_FORWARD := -3.0
const ROLL_TRIGGER := 300.0
const ROLL_SPEED := 5.0
const POUNCE_TRIGGER := 270.0
const POUNCE_VY := -12.5
const POUNCE_FORWARD := -6.5
const BURROW_SPEED := -2.5
const SURFACE_DISTANCE := 170.0
const WAVE_AMP := 35.0
const WAVE_FREQ := 2.4
const EGG_GRAVITY := EnemyShot.EGG_G

const BLINK_RED := Color(1.0, 0.45, 0.35)
const BLINK_YELLOW := Color(1.0, 0.95, 0.4)
const ENRAGED := Color(1.0, 0.72, 0.72)

var kind := ""
var cfg: Dictionary
var hp := 1
var max_hp := 1
var is_boss := false
var boss_state := "enter"  # enter -> idle -> warn -> charge -> (off screen) enter
var boss_timer := 0.0
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

# --- smarter behaviour ---
var speed_mult := 1.0
var shielded := false
var enraged := false
var curled := false        # hedgehog rolled into a ball: shots bounce off
var can_enrage := false    # set by scale_for_run (run 4+)
var flash := 0.0           # white flash after a hit (s)
var shield_flash := 0.0
var life := 0.0            # scaled seconds alive (drives the sine wave)
var base_y := 0.0
var ai := ""
var ai_state := "cruise"   # charge/dive: cruise -> telegraph -> go ; hop: walk/air
var ai_timer := 0.0
var vx := 0.0              # dive / hop velocity (px per tick)
var vy := 0.0
var can_shoot := false
var shoot_kind := ""
var shoot_cd := 0.0
var shoot_telegraph := 0.0
var pending_shot := ""     # kind of projectile Game should create this tick
var _blink := Color.WHITE  # WHITE = not blinking


static func create(enemy_kind: String, px: float, py: float) -> Enemy:
    var e := Enemy.new()
    e.setup(enemy_kind, px, py)
    return e


## The boss for the n-th boss run (0-based). Later cycles have more hp.
static func create_boss(tier: int, px: float, py: float) -> Enemy:
    var e := Enemy.create(BOSSES[tier % BOSSES.size()], px, py)
    e.hp += 4 * (tier / BOSSES.size())
    e.max_hp = e.hp
    return e


func setup(enemy_kind: String, px: float, py: float) -> void:
    kind = enemy_kind
    cfg = KINDS[kind]
    w = cfg["w"]
    h = cfg["h"]
    hp = cfg["hp"]
    max_hp = hp
    is_boss = cfg.get("boss", false)
    hitbox = cfg["hit"]
    air = cfg["air"]
    ai = cfg.get("ai", "")
    shoot_kind = cfg.get("shoot", "")
    shoot_cd = randf_range(1.0, 2.5)
    place(px, py)
    base_y = py
    prev_x = x
    if kind == "mole":
        underground = true
        mole_interval = randf_range(3.0, 5.0)
    if ai == "hop":
        ai_timer = randf_range(0.6, 1.4)
    _show_frame(0)


## Remember the current y as the resting height (call after moving a new enemy).
func anchor() -> void:
    base_y = y


## Make this enemy tougher / smarter for run `run_number` (1 = first run):
## faster, armored (more hp), shielded, and able to shoot from `shoot_from`.
func scale_for_run(run_number: int) -> void:
    can_enrage = run_number >= ENRAGE_FROM_RUN
    if is_boss:
        return
    speed_mult = 1.0 + minf(0.05 * (run_number - 1), 0.5)
    hp += (run_number - 1) / 3
    max_hp = hp
    can_shoot = shoot_kind != "" and run_number >= int(cfg.get("shoot_from", 99))
    shielded = cfg.get("can_shield", false) and run_number >= SHIELD_FROM_RUN and randf() < 0.4


func _show_frame(i: int) -> void:
    frame_idx = i
    set_sprite(Cfg.tex(cfg["frames"][i]))


## Can an acorn hurt it / can it hurt the squirrel right now?
func hittable() -> bool:
    if not active or defeated:
        return false
    return not (kind == "mole" and underground)


## Does the shield (or the hedgehog's curled-up spikes) stop `sh`? A shield only
## stops shots coming from the front, a ball stops everything; neither stops
## shots that break shields (rainbow beam) - bombs use blast damage instead.
func blocks(sh: Shot) -> bool:
    if sh.breaks_shield:
        return false
    return curled or (shielded and sh.vx > 0.0)


## Apply a hit. Returns true if this hit defeated it.
func hit(damage := 1) -> bool:
    hp -= damage
    flash = 0.12
    if hp <= 0:
        defeated = true
        shielded = false
        _apply_tint()
        queue_redraw()
        return true
    if can_enrage and max_hp >= 2 and hp * 2 <= max_hp:
        enraged = true  # wounded: faster and angrier
    _apply_tint()
    queue_redraw()
    return false


## The projectile kind to fire this tick ("" = none); clears the request.
func take_shot() -> String:
    var s := pending_shot
    pending_shot = ""
    return s


## `target` is the squirrel's collision rect (zero-size = unknown).
func update(scroll_speed: float, delta: float, target := Rect2()) -> void:
    life += delta
    flash = maxf(0.0, flash - delta)
    shield_flash = maxf(0.0, shield_flash - delta)
    _blink = Color.WHITE
    if defeated:
        _update_defeated(scroll_speed)
    elif is_boss:
        _update_boss(scroll_speed, delta)
    else:
        match ai:
            "burrow":
                _update_mole(scroll_speed, delta, target)
            "charge":
                _update_charger(scroll_speed, delta, target)
            "dive":
                _update_diver(scroll_speed, delta, target)
            "hop":
                _update_hopper(scroll_speed, delta)
            "roll":
                _update_roller(scroll_speed, delta, target)
            "pounce":
                _update_pouncer(scroll_speed, delta, target)
            _:
                _update_walker(scroll_speed, delta)
                if ai == "wave":
                    y = base_y + cfg.get("wave_amp", WAVE_AMP) * sin(life * cfg.get("wave_freq", WAVE_FREQ))
        _update_shooting(delta, target)
    _apply_tint()
    if shielded or shield_flash > 0.0 or (max_hp > 1 and hp < max_hp):
        queue_redraw()
    sync()


func _forward() -> float:
    return cfg["forward"] * speed_mult * (1.6 if enraged else 1.0) * Cfg.time_scale


func _animate(delta: float) -> void:
    anim_timer += delta
    if anim_timer >= cfg["interval"]:
        anim_timer = 0.0
        var n: int = cfg.get("anim_frames", cfg["frames"].size())
        _show_frame(randi() % n if cfg["random_frames"] else (frame_idx + 1) % n)


func _update_walker(scroll_speed: float, delta: float) -> void:
    prev_x = x
    x -= scroll_speed
    x += _forward()
    _animate(delta)
    if x + w < 0.0:
        active = false


## Distance between this enemy's front and the squirrel's front (+ = ahead of it).
func _gap_to(target: Rect2) -> float:
    return rect().position.x - target.end.x


func _update_charger(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    _animate(delta)
    match ai_state:
        "cruise":
            x -= scroll_speed
            x += _forward()
            if target.size != Vector2.ZERO and _gap_to(target) < CHARGE_TRIGGER and _gap_to(target) > 0.0:
                ai_state = "telegraph"
                ai_timer = 0.0
        "telegraph":  # plants its feet: only the world moves it
            x -= scroll_speed
            ai_timer += delta
            _blink = BLINK_RED if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= TELEGRAPH:
                ai_state = "go"
        "go":
            x -= scroll_speed + CHARGE_SPEED * speed_mult * Cfg.time_scale
    if x + w < 0.0:
        active = false


func _update_diver(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    _animate(delta)
    match ai_state:
        "cruise":
            x -= scroll_speed
            x += _forward()
            if target.size != Vector2.ZERO and _gap_to(target) < DIVE_TRIGGER:
                ai_state = "telegraph"
                ai_timer = 0.0
        "telegraph":
            x -= scroll_speed * 0.5
            ai_timer += delta
            _blink = BLINK_RED if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= TELEGRAPH:
                # lock on to where the squirrel is NOW; it can still dodge by moving
                var dir := (target.get_center() - rect().get_center()).normalized()
                vx = dir.x * DIVE_SPEED * speed_mult
                vy = dir.y * DIVE_SPEED * speed_mult
                ai_state = "go"
        "go":
            x += vx * Cfg.time_scale - scroll_speed  # own velocity, carried by the world too
            y += vy * Cfg.time_scale
    if x + w < 0.0 or y > Cfg.SCREEN_H or (ai_state == "go" and x > Cfg.SCREEN_W + 120.0):
        active = false


func _update_roller(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    var ts := Cfg.time_scale
    match ai_state:
        "cruise":
            x -= scroll_speed
            x += _forward()
            _animate(delta)
            if target.size != Vector2.ZERO and _gap_to(target) < ROLL_TRIGGER and _gap_to(target) > 0.0:
                ai_state = "telegraph"
                ai_timer = 0.0
        "telegraph":  # tucks its head in
            x -= scroll_speed
            ai_timer += delta
            _blink = BLINK_YELLOW if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= TELEGRAPH:
                ai_state = "ball"
                curled = true
                _show_frame(2)
                sprite.centered = true  # spin around its middle
                sprite.position = Vector2(w / 2.0, h / 2.0)
        "ball":
            x -= scroll_speed + ROLL_SPEED * speed_mult * ts
            sprite.rotation -= 0.4 * ts
    if x + w < 0.0:
        active = false


func _update_pouncer(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    var ts := Cfg.time_scale
    match ai_state:
        "cruise", "run":
            x -= scroll_speed
            x += _forward()
            _animate(delta)
            if ai_state == "cruise" and target.size != Vector2.ZERO and _gap_to(target) < POUNCE_TRIGGER and _gap_to(target) > 0.0:
                ai_state = "telegraph"
                ai_timer = 0.0
        "telegraph":  # crouches
            x -= scroll_speed
            ai_timer += delta
            _blink = BLINK_RED if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= TELEGRAPH * 0.8:
                ai_state = "air"
                vy = POUNCE_VY
        "air":
            vy += Cfg.GRAVITY * ts
            y += vy * ts
            x -= scroll_speed
            x += POUNCE_FORWARD * speed_mult * ts
            if y >= base_y:
                y = base_y
                vy = 0.0
                ai_state = "run"
    if x + w < 0.0:
        active = false


func _update_hopper(scroll_speed: float, delta: float) -> void:
    prev_x = x
    var ts := Cfg.time_scale
    _animate(delta)
    x -= scroll_speed
    x += _forward()
    if ai_state == "air":
        vy += Cfg.GRAVITY * ts
        y += vy * ts
        x += HOP_FORWARD * speed_mult * ts
        if y >= base_y:
            y = base_y
            vy = 0.0
            ai_state = "walk"
            ai_timer = randf_range(1.0, 2.0) / (1.5 if enraged else 1.0)
    else:
        ai_timer -= delta
        if ai_timer <= 0.0:
            ai_state = "air"
            vy = HOP_SPEED
    if x + w < 0.0:
        active = false


func _update_boss(scroll_speed: float, delta: float) -> void:
    prev_x = x
    var ts := Cfg.time_scale
    _animate(delta)
    var idle_time := BOSS_IDLE_TIME * (0.5 if enraged else 1.0)
    match boss_state:
        "enter":
            x -= scroll_speed + 3.0 * ts
            if x <= Cfg.SCREEN_W - w - BOSS_STOP_MARGIN:
                boss_state = "idle"
                boss_timer = 0.0
                shoot_cd = 1.0
        "idle":
            boss_timer += delta
            shoot_cd -= delta
            if shoot_cd <= 0.0:  # spits a fireball at the squirrel
                pending_shot = "fire"
                shoot_cd = 1.2 if enraged else 2.0
            if boss_timer >= idle_time:
                boss_state = "warn"
                boss_timer = 0.0
        "warn":
            boss_timer += delta
            _blink = BLINK_RED if int(boss_timer * 12.0) % 2 == 0 else Color.WHITE
            if boss_timer >= BOSS_WARN_TIME:
                boss_state = "charge"
        "charge":
            x -= scroll_speed + (BOSS_CHARGE_SPEED * (1.3 if enraged else 1.0)) * ts
            if x + w < 0.0:
                x = Cfg.SPAWN_X  # comes round again
                boss_state = "enter"


func _update_mole(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    x -= scroll_speed
    mole_timer += delta
    if underground:
        var ahead := target.size != Vector2.ZERO and _gap_to(target) > 0.0
        if ahead:
            x += BURROW_SPEED * speed_mult * Cfg.time_scale  # tunnels toward the squirrel
            if _gap_to(target) < SURFACE_DISTANCE:  # ...and pops up right in front of it
                underground = false
                mole_timer = 0.0
                mole_interval = randf_range(3.0, 5.0)
                _show_frame(1)
    if mole_timer >= mole_interval:
        underground = not underground
        mole_timer = 0.0
        mole_interval = randf_range(3.0, 7.0)
        _show_frame(0 if underground else 1)
    if x + w < 0.0:
        active = false


func _update_defeated(scroll_speed: float) -> void:
    var ts := Cfg.time_scale
    if not fall_started:
        fall_started = true
        fall_vy = -sqrt(2.0 * Cfg.GRAVITY * DEFEAT_HOP_HEIGHT)  # hop up first
        if kind == "mole":
            underground = false
            _show_frame(1)
    fall_vy += Cfg.GRAVITY * ts
    y += fall_vy * ts
    x += cfg["fall_vx"] * ts
    if kind == "mole":
        x -= scroll_speed  # a defeated mole is still carried by the ground
    if x + w < 0.0 or y > Cfg.SCREEN_H:
        active = false


# ---------------------------------------------------------------- shooting

## Later enemies shoot: skunks spray gas, birds drop eggs, pterodactyls spit
## fire. Each blinks yellow for TELEGRAPH seconds before firing.
func _update_shooting(delta: float, target: Rect2) -> void:
    if not can_shoot or target.size == Vector2.ZERO:
        return
    var r := rect()
    if r.position.x > Cfg.SCREEN_W - 30.0 or r.end.x < target.end.x + 30.0:
        return  # not on screen yet, or already behind the squirrel
    if shoot_telegraph > 0.0:
        shoot_telegraph -= delta
        _blink = BLINK_YELLOW if int(shoot_telegraph * 14.0) % 2 == 0 else Color.WHITE
        if shoot_telegraph <= 0.0:
            pending_shot = shoot_kind
            shoot_cd = randf_range(3.0, 4.5)
        return
    shoot_cd -= delta
    if shoot_cd <= 0.0 and _shot_lined_up(r, target):
        shoot_telegraph = TELEGRAPH


func _shot_lined_up(r: Rect2, target: Rect2) -> bool:
    var dx := r.position.x - target.end.x
    match shoot_kind:
        "gas":
            return dx > 140.0 and dx < 520.0
        "fire":
            return dx > 200.0 and dx < 620.0
        "egg":
            # the egg keeps the bird's drift: drop it early enough to land on the squirrel
            var fall := maxf(target.position.y - r.end.y, 1.0)
            var frames := sqrt(2.0 * fall / EGG_GRAVITY) + TELEGRAPH * 60.0
            var lead := (Cfg.SCROLL_SPEED + 0.5) * frames
            return absf((r.get_center().x - target.get_center().x) - lead) < 30.0
    return false


# ---------------------------------------------------------------- look

func _apply_tint() -> void:
    if sprite == null:
        return
    if flash > 0.0:
        sprite.modulate = Color(2.0, 2.0, 2.0)
    elif _blink != Color.WHITE:
        sprite.modulate = _blink
    elif enraged and not defeated:
        sprite.modulate = ENRAGED
    else:
        sprite.modulate = Color.WHITE


func _draw() -> void:
    if defeated:
        return
    var hb := Rect2(hitbox.position.x * w, hitbox.position.y * h, hitbox.size.x * w, hitbox.size.y * h)
    if shielded:  # a shield held out in front (left side)
        var sx := hb.position.x - 10.0
        var top := hb.position.y - 4.0
        var bottom := hb.end.y + 2.0
        var mid := (top + bottom) / 2.0
        var col := Color(0.85, 0.95, 1.0) if shield_flash > 0.0 else Color(0.45, 0.65, 0.95)
        var pts := PackedVector2Array([Vector2(sx + 8, top), Vector2(sx, top + 8), Vector2(sx - 2, mid),
            Vector2(sx, bottom - 8), Vector2(sx + 8, bottom), Vector2(sx + 12, mid)])
        draw_colored_polygon(pts, col)
        draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), Color(0.15, 0.25, 0.5), 2.0)
    if not is_boss and max_hp > 1 and hp < max_hp:  # little health bar once wounded
        var bw := minf(hb.size.x, 46.0)
        var bx := hb.position.x + (hb.size.x - bw) / 2.0
        var by := hb.position.y - 9.0
        draw_rect(Rect2(bx, by, bw, 5.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(bx, by, bw * float(hp) / max_hp, 5.0), Color(0.9, 0.2, 0.2))
