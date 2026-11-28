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
##    throw   raccoon: walks, stands up, throws a nut at you, eats, walks on
## Kinds marked "private_only" (bee, owl, raccoon) use licensed local-only art: see is_available().
## (owl and bee use `wave` with their own "wave_amp" / "wave_freq": a slow wide
## swoop and a fast jittery zigzag)
## Extra hp from armor in later runs; `enraged` below
## half hp (faster, from run 4 only). Shooting ("shoot": gas / fire) only from `shoot_from`.
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
        "ai": "charge",
    },
    "croco": {
        "hit": Rect2(0.07, 0.42, 0.86, 0.57), "coins": 6,
        "w": 80.0, "h": 80.0, "air": false, "hp": 2,
        "frames": ["croco1.png", "croco2.png", "croco3.png"],
        "interval": 0.75, "random_frames": true, "forward": -1.0, "fall_vx": -2.5,
        "ai": "hop",
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
        "ai": "wave",  # (a bird never shoots or drops anything)
    },
    "ptero": {
        "hit": Rect2(0.19, 0.18, 0.55, 0.54), "coins": 8,
        "w": 90.0, "h": 60.0, "air": true, "hp": 2,
        "frames": ["ptero1.png", "ptero2.png"],
        "interval": 1.0, "random_frames": false, "forward": -1.0, "fall_vx": -3.0,
        "ai": "dive", "shoot": "fire", "shoot_from": 5,
    },
    # The raccoon (licensed art, local-only - see CREDITS.md) walks in, then stands up and
    # throws nuts at the squirrel. Without its art files it simply does not spawn.
    "raccoon": {
        "hit": Rect2(0.03, 0.49, 0.91, 0.46), "hit_stand": Rect2(0.16, 0.28, 0.71, 0.64), "coins": 9,
        "w": 100.0, "h": 75.0, "air": false, "hp": 2,
        "frames": [], "private_only": true,
        "interval": 0.13, "random_frames": false, "forward": -1.0, "fall_vx": -2.5,
        "ai": "throw",
        "private": {
            "frames": ["res://private/raccoon_1.png", "res://private/raccoon_2.png", "res://private/raccoon_3.png",
                "res://private/raccoon_4.png", "res://private/raccoon_5.png", "res://private/raccoon_6.png",
                "res://private/raccoon_7.png", "res://private/raccoon_8.png", "res://private/raccoon_9.png"],
            "anim_frames": 4,  # frames 1-4 are the walk cycle; 5 holds the pot, 6 raises it, 8 sits up, 9 eats
        },
    },
    # The owl (licensed art, local-only) swoops in slow wide waves, blinking now and then; it
    # does not spawn without its art files.
    "owl": {
        "hit": Rect2(0.08, 0.08, 0.84, 0.86), "coins": 8,
        "w": 52.0, "h": 80.0, "air": true, "hp": 2,
        "frames": [], "private_only": true,
        "interval": 0.28, "random_frames": false, "forward": -1.0, "fall_vx": -2.5,
        "ai": "wave", "wave_amp": 105.0, "wave_freq": 1.5,
        "private": {
            # eyes open, open, open, blink, open, open, sleepy: a blinking, drowsy owl
            "frames": ["res://private/owl_1.png", "res://private/owl_1.png", "res://private/owl_1.png", "res://private/owl_2.png",
                "res://private/owl_1.png", "res://private/owl_1.png", "res://private/owl_3.png"],
        },
    },
    # The bee swarm (licensed art, local-only) does not spawn without its art files.
    "bee": {
        "hit": Rect2(0.15, 0.18, 0.74, 0.72), "coins": 2,
        "w": 62.0, "h": 38.0, "air": true, "hp": 1,
        "frames": [], "private_only": true,
        "interval": 0.07, "random_frames": false, "forward": -1.6, "fall_vx": -2.5,
        "ai": "wave", "wave_amp": 50.0, "wave_freq": 7.0,
        "private": {
            "frames": ["res://private/bee_1.png", "res://private/bee_2.png", "res://private/bee_3.png", "res://private/bee_4.png"],
        },
    },
    # Bosses: big versions of ordinary sprites. They walk in, stand and spit
    # fire, then blink red and charge across the screen - jump over (or onto) them.
    "boss_beaver": {
        "hit": Rect2(0.06, 0.14, 0.91, 0.84), "coins": 40, "boss": true,
        "w": 230.0, "h": 102.0, "air": false, "hp": 10,
        "frames": ["beaver1.png", "beaver2.png", "beaver3.png"],
        "interval": 0.2, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
    },
    # The second boss is a cleaver-wielding boar - but its art is licensed and kept
    # out of the public repo (godot/private/, see CREDITS.md). Without those files
    # it falls back to a giant croco (the defaults below); with them the "private"
    # entry overrides frames, size and hitbox.
    "boss_boar": {
        "hit": Rect2(0.07, 0.42, 0.86, 0.57), "coins": 60, "boss": true,
        "w": 230.0, "h": 136.0, "air": false, "hp": 14,
        "frames": ["croco1.png", "croco2.png", "croco3.png"],
        "interval": 0.5, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
        "private": {
            "frames": ["res://private/boar_1.png", "res://private/boar_2.png", "res://private/boar_3.png"],
            "w": 125.0, "h": 140.0, "hit": Rect2(0.06, 0.12, 0.75, 0.83),  # 116 px tall: still jumpable
            "interval": 0.28,
        },
    },
    # The third boss is a pink monster that lobs viruses (a tail swing throws them). Its art is
    # licensed and local-only too (godot/private/virus_1..9.png, see CREDITS.md); without it a giant
    # skunk takes its place, still lobbing viruses (it just has no throwing poses).
    "boss_virus": {
        "hit": Rect2(0.04, 0.53, 0.84, 0.47), "coins": 80, "boss": true, "lobs_virus": true,
        "w": 210.0, "h": 166.0, "air": false, "hp": 18,
        "frames": ["skunk_1.png", "skunk_2.png", "skunk_3.png"],
        "interval": 0.6, "random_frames": false, "forward": 0.0, "fall_vx": -1.0,
        "private": {
            # frames 1-4: walk cycle; 5-9: the throw (raises the tail, tail holds the virus, lets go, follow-through)
            "frames": ["res://private/virus_1.png", "res://private/virus_2.png", "res://private/virus_3.png",
                "res://private/virus_4.png", "res://private/virus_5.png", "res://private/virus_6.png",
                "res://private/virus_7.png", "res://private/virus_8.png", "res://private/virus_9.png"],
            "anim_frames": 4, "interval": 0.18,
            # the art's canvas is 365x265 (body on the right, room for the long tail on the left):
            # 190 px tall puts the body at about 120 px - still jumpable
            "w": 262.0, "h": 190.0, "hit": Rect2(0.46, 0.34, 0.52, 0.64),
        },
    },
}

const DEFEAT_HOP_HEIGHT := 20.0

# One boss every 3rd run, cycling through BOSSES.
const BOSSES: Array[String] = ["boss_beaver", "boss_boar", "boss_virus"]
const BOSS_STOP_MARGIN := 40.0
const BOSS_IDLE_TIME := 2.0
const BOSS_WARN_TIME := 0.8
## The virus boss's throw (seconds into it when each throwing frame, 5-9 of its art, ends). The tail
## holds the virus during frame 7 and lets go at its end: that is when the virus leaves.
const VIRUS_THROW_ENDS := [0.3, 0.55, 0.8, 1.0, 1.3]
const VIRUS_FIRST_FRAME := 4
const VIRUS_RELEASE_AT := 0.8
const VIRUS_THROW_GAP := 1.7    # seconds between two throws while it stands (x0.7 when enraged)
const BOSS_CHARGE_SPEED := 7.0

const ENRAGE_FROM_RUN := 4   # no angry enemies in the first runs
const TELEGRAPH := 0.45        # warning blink before a shot / charge / dive
const CHARGE_TRIGGER := 330.0  # beaver charges when this close
const CHARGE_SPEED := 6.0
const DIVE_TRIGGER := 360.0
const DIVE_SPEED := 7.5
const HOP_SPEED := -11.5
const HOP_FORWARD := -3.0
const THROW_MIN_GAP := 170.0   # the raccoon throws when the squirrel is between these distances away
const THROW_MAX_GAP := 430.0
const THROW_STAND := 0.4       # sits up (blinks yellow), then raises the nut...
const THROW_WIND := 0.25
const THROW_RELEASE := 0.3     # ...and throws it
const THROW_REST := 0.7        # eats while the next nut is prepared
const FRAME_HOLD := 4
const FRAME_RAISE := 5
const FRAME_SIT := 7
const FRAME_EAT := 8
const BURROW_SPEED := -2.5
const SURFACE_DISTANCE := 170.0
const WAVE_AMP := 35.0
const WAVE_FREQ := 2.4

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

var ridden := false       # bird only: the squirrel is standing on it, so it flies at the speed of the scrolling (stays put on screen)
var fall_started := false
var fall_vy := 0.0

# --- smarter behaviour ---
var speed_mult := 1.0
var enraged := false
var can_enrage := false    # set by scale_for_run (run 4+)
var flash := 0.0           # white flash after a hit (s)
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
var virus_t := -1.0        # the virus boss's throw in progress: seconds into it (-1 = not throwing)
var _virus_released := false
var pending_sound := ""    # sound cue for Game to play ("warn", "stomp", "dive"...)
var _blink := Color.WHITE  # WHITE = not blinking


static func create(enemy_kind: String, px: float, py: float) -> Enemy:
    var e := Enemy.new()
    e.setup(enemy_kind, px, py)
    return e


## True when every frame of the optional local-only art of `kind_cfg` is present.
## Can this kind be spawned? Kinds that only exist as licensed local-only art
## (bee, raccoon) need their frames in godot/private/; everything else always can.
static func is_available(enemy_kind: String) -> bool:
    var c: Dictionary = KINDS[enemy_kind]
    return not c.get("private_only", false) or Enemy.private_art_available(c)


static func private_art_available(kind_cfg: Dictionary) -> bool:
    for f: String in kind_cfg["private"]["frames"]:
        if not ResourceLoader.exists(f):
            return false
    return true


## The boss for the n-th boss run (0-based). Later cycles have more hp.
static func create_boss(tier: int, px: float, py: float) -> Enemy:
    var e := Enemy.create(BOSSES[tier % BOSSES.size()], px, py)
    e.hp += 4 * (tier / BOSSES.size())
    e.max_hp = e.hp
    return e


func setup(enemy_kind: String, px: float, py: float) -> void:
    kind = enemy_kind
    cfg = KINDS[kind]
    if cfg.has("private") and Enemy.private_art_available(cfg):
        cfg = cfg.merged(cfg["private"], true)  # the local-only art replaces the stand-in (or is the only art)
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
    if ai == "throw":
        ai_timer = randf_range(0.5, 1.2)  # a short walk before the first throw
    _show_frame(0)


## Remember the current y as the resting height (call after moving a new enemy).
func anchor() -> void:
    base_y = y


## Make this enemy tougher / smarter for run `run_number` (1 = first run):
## faster, armored (more hp), and able to shoot from `shoot_from`.
func scale_for_run(run_number: int) -> void:
    can_enrage = run_number >= ENRAGE_FROM_RUN
    if is_boss:
        return
    speed_mult = 1.0 + minf(0.05 * (run_number - 1), 0.5)
    hp += (run_number - 1) / 3
    max_hp = hp
    can_shoot = shoot_kind != "" and run_number >= int(cfg.get("shoot_from", 99))


func _show_frame(i: int) -> void:
    frame_idx = i
    set_sprite(Cfg.tex(cfg["frames"][i]))
    sprite.flip_h = ridden


## The squirrel hops on (or off) this bird: it turns to face right (the art faces left)
## and its collision box turns with it, so the squirrel stands on what it can see.
func set_ridden(on: bool) -> void:
    if on == ridden:
        return
    ridden = on
    var hb: Rect2 = cfg["hit"]
    hitbox = Rect2(1.0 - hb.end.x, hb.position.y, hb.size.x, hb.size.y) if on else hb
    if sprite:
        sprite.flip_h = on


## Can an acorn hurt it / can it hurt the squirrel right now?
func hittable() -> bool:
    if not active or defeated:
        return false
    return not (kind == "mole" and underground)


## Apply a hit. Returns true if this hit defeated it.
func hit(damage := 1) -> bool:
    hp -= damage
    flash = 0.12
    if hp <= 0:
        defeated = true
        _apply_tint()
        queue_redraw()
        return true
    if can_enrage and max_hp >= 2 and hp * 2 <= max_hp:
        enraged = true  # wounded: faster and angrier
    _apply_tint()
    queue_redraw()
    return false


## The sound cue to play this tick ("" = none); clears the request.
func take_sound() -> String:
    var s := pending_sound
    pending_sound = ""
    return s


## The projectile kind to fire this tick ("" = none); clears the request.
func take_shot() -> String:
    var s := pending_shot
    pending_shot = ""
    return s


## `target` is the squirrel's collision rect (zero-size = unknown).
func update(scroll_speed: float, delta: float, target := Rect2()) -> void:
    life += delta
    flash = maxf(0.0, flash - delta)
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
            "throw":
                _update_thrower(scroll_speed, delta, target)
            _:
                _update_walker(scroll_speed, delta)
                if ai == "wave":
                    y = base_y + cfg.get("wave_amp", WAVE_AMP) * sin(life * cfg.get("wave_freq", WAVE_FREQ))
        if not ridden:  # a bird doesn't bomb its own rider
            _update_shooting(delta, target)
    _apply_tint()
    if max_hp > 1 and hp < max_hp:
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
    if ridden:
        x += scroll_speed  # flies as fast as the world scrolls: it stays where it is on screen, rider on its back
    else:
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
                pending_sound = "warn"
        "telegraph":  # plants its feet: only the world moves it
            x -= scroll_speed
            ai_timer += delta
            _blink = BLINK_RED if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= TELEGRAPH:
                ai_state = "go"
                pending_sound = "stomp"
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
                pending_sound = "warn"
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
                pending_sound = "dive"
        "go":
            x += vx * Cfg.time_scale - scroll_speed  # own velocity, carried by the world too
            y += vy * Cfg.time_scale
    if x + w < 0.0 or y > Cfg.SCREEN_H or (ai_state == "go" and x > Cfg.SCREEN_W + 120.0):
        active = false


func _update_thrower(scroll_speed: float, delta: float, target: Rect2) -> void:
    prev_x = x
    match ai_state:
        "cruise":  # prowling
            x -= scroll_speed
            x += _forward()
            _animate(delta)
            ai_timer -= delta
            var gap := _gap_to(target)
            if ai_timer <= 0.0 and target.size != Vector2.ZERO and gap > THROW_MIN_GAP and gap < THROW_MAX_GAP and x < Cfg.SCREEN_W - w:
                ai_state = "stand"
                ai_timer = 0.0
                hitbox = cfg["hit_stand"]
                _show_frame(FRAME_SIT)
                pending_sound = "warn"
        "stand":  # sits up: a visible warning that a nut is coming
            x -= scroll_speed
            ai_timer += delta
            _blink = BLINK_YELLOW if int(ai_timer * 14.0) % 2 == 0 else Color.WHITE
            if ai_timer >= THROW_STAND:
                ai_state = "wind"
                ai_timer = 0.0
                _show_frame(FRAME_HOLD)
        "wind":  # takes the nut out of the pot
            x -= scroll_speed
            ai_timer += delta
            if ai_timer >= THROW_WIND:
                ai_state = "release"
                ai_timer = 0.0
                _show_frame(FRAME_RAISE)
                pending_shot = "nut"
                pending_sound = "throw_acorn"
        "release":
            x -= scroll_speed
            ai_timer += delta
            if ai_timer >= THROW_RELEASE:
                ai_state = "rest"
                ai_timer = 0.0
                _show_frame(FRAME_EAT)
        "rest":  # snacks, then walks on
            x -= scroll_speed
            ai_timer += delta
            if ai_timer >= THROW_REST / (1.5 if enraged else 1.0):
                ai_state = "cruise"
                ai_timer = randf_range(1.2, 2.2)
                hitbox = cfg["hit"]
                _show_frame(0)
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
    if virus_t < 0.0:  # (a throw plays its own poses)
        _animate(delta)
    var lobs: bool = cfg.get("lobs_virus", false)
    var idle_time := BOSS_IDLE_TIME * (0.5 if enraged else 1.0) * (1.7 if lobs else 1.0)
    match boss_state:
        "enter":
            x -= scroll_speed + 3.0 * ts
            if x <= Cfg.SCREEN_W - w - BOSS_STOP_MARGIN:
                boss_state = "idle"
                boss_timer = 0.0
                shoot_cd = 0.2 if lobs else 1.0
        "idle":
            boss_timer += delta
            shoot_cd -= delta
            if lobs:  # lobs viruses with its tail (a pose sequence), instead of spitting fire
                _update_virus_throw(delta)
            elif shoot_cd <= 0.0:  # spits a fireball at the squirrel
                pending_shot = "fire"
                shoot_cd = 1.2 if enraged else 2.0
            if boss_timer >= idle_time and virus_t < 0.0:  # (never cut a throw short)
                boss_state = "warn"
                boss_timer = 0.0
                pending_sound = "warn"
        "warn":
            boss_timer += delta
            _blink = BLINK_RED if int(boss_timer * 12.0) % 2 == 0 else Color.WHITE
            if boss_timer >= BOSS_WARN_TIME:
                boss_state = "charge"
                pending_sound = "stomp"
        "charge":
            x -= scroll_speed + (BOSS_CHARGE_SPEED * (1.3 if enraged else 1.0)) * ts
            if x + w < 0.0:
                x = Cfg.SPAWN_X  # comes round again
                boss_state = "enter"


## One tick of the virus boss's throw: starts when the cooldown is over, plays frames 5-9 of its
## art (the first ones blink yellow as the warning), and sends the virus when the tail lets go.
func _update_virus_throw(delta: float) -> void:
    if virus_t < 0.0:
        if shoot_cd > 0.0:
            return
        virus_t = 0.0
        _virus_released = false
        pending_sound = "warn"
    virus_t += delta
    var i := 0
    while i < VIRUS_THROW_ENDS.size() and virus_t >= VIRUS_THROW_ENDS[i]:
        i += 1
    if i >= VIRUS_THROW_ENDS.size():  # follow-through over: back to walking
        virus_t = -1.0
        shoot_cd = VIRUS_THROW_GAP * (0.7 if enraged else 1.0)
        _blink = Color.WHITE
        _show_frame(0)
        return
    if not _virus_released and virus_t >= VIRUS_RELEASE_AT:
        _virus_released = true
        pending_shot = "virus"
    _blink = BLINK_YELLOW if i < 2 and int(virus_t * 14.0) % 2 == 0 else Color.WHITE
    if cfg["frames"].size() > VIRUS_FIRST_FRAME + i:  # (the stand-in art has no throwing poses)
        _show_frame(VIRUS_FIRST_FRAME + i)


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
                pending_sound = "mole_pop"
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

## Later enemies shoot: skunks spray gas, pterodactyls spit
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
        pending_sound = "warn"


func _shot_lined_up(r: Rect2, target: Rect2) -> bool:
    var dx := r.position.x - target.end.x
    match shoot_kind:
        "gas":
            return dx > 140.0 and dx < 520.0
        "fire":
            return dx > 200.0 and dx < 620.0
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
    if not is_boss and max_hp > 1 and hp < max_hp:  # little health bar once wounded
        var bw := minf(hb.size.x, 46.0)
        var bx := hb.position.x + (hb.size.x - bw) / 2.0
        var by := hb.position.y - 9.0
        draw_rect(Rect2(bx, by, bw, 5.0), Color(0, 0, 0, 0.6))
        draw_rect(Rect2(bx, by, bw * float(hp) / max_hp, 5.0), Color(0.9, 0.2, 0.2))
