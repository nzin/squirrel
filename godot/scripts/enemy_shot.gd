class_name EnemyShot
extends Entity
## A projectile fired by an enemy. Lethal on any contact with the squirrel
## (unlike enemies, which only hurt on a head-on crossing); the player's
## acorns destroy it, and so does the Matrix Fist.
##   gas   skunk: a slow stink cloud rolling along the ground - jump over it
##   fire  ptero / boss: a fireball aimed at the squirrel
##   nut   raccoon: thrown in a horizontal straight line from its front paws (jump over it)
##   virus boss: lobbed in a high arc that comes down on the squirrel (jump, or shoot it down)

const VIRUS_FLIGHT := 75.0  # physics ticks a lobbed virus stays in the air
## Optional licensed picture of the virus (cut from the boss art), local-only: drawn as a spiky ball otherwise.
const VIRUS_ART := "res://private/virus_bomb.png"
static var _virus_art: Texture2D = null
static var _virus_checked := false
const SPECS := {
    "gas":  {"w": 36.0, "h": 28.0, "speed": 4.2, "gravity": 0.0},
    "fire": {"w": 26.0, "h": 26.0, "speed": 6.0, "gravity": 0.0},
    "nut":  {"w": 18.0, "h": 20.0, "speed": 7.0, "gravity": 0.0},  # thrown in a straight horizontal line
    "virus": {"w": 40.0, "h": 40.0, "speed": 0.0, "gravity": 0.35},  # aimed lob: see setup()
}

var kind := "gas"
var vx := 0.0
var vy := 0.0
var gravity := 0.0
var age := 0.0
var hurt_player := false  # already cost the (armored) squirrel a health point: it hurts once, not every tick


## `aim` = unit direction for "fire"; for "virus" it is the point to land on; other kinds have a fixed path.
static func create(shot_kind: String, px: float, py: float, aim := Vector2.LEFT) -> EnemyShot:
    var s := EnemyShot.new()
    s.setup(shot_kind, px, py, aim)
    return s


func setup(shot_kind: String, px: float, py: float, aim: Vector2) -> void:
    kind = shot_kind
    var spec: Dictionary = SPECS[kind]
    w = spec["w"]
    h = spec["h"]
    gravity = spec["gravity"]
    var speed: float = spec["speed"]
    if kind == "fire":
        vx = aim.x * speed
        vy = aim.y * speed
    elif kind == "virus":  # a lob that reaches `aim` (the squirrel's feet) after VIRUS_FLIGHT ticks
        var from := Vector2(px, py)
        vx = (aim.x - from.x) / VIRUS_FLIGHT
        vy = (aim.y - from.y - 0.5 * gravity * VIRUS_FLIGHT * VIRUS_FLIGHT) / VIRUS_FLIGHT
    elif kind == "nut":  # straight and level, in front of the thrower, like the gas cloud
        vx = -speed
    else:
        vx = -speed
    place(px - w / 2.0, py - h / 2.0)


## The optional virus picture, or null when the local art is absent.
static func virus_art() -> Texture2D:
    if not _virus_checked:
        _virus_checked = true
        if ResourceLoader.exists(VIRUS_ART):
            _virus_art = load(VIRUS_ART)
    return _virus_art


func update(delta: float) -> void:
    var ts := Cfg.time_scale
    age += delta
    vy += gravity * ts
    x += vx * ts
    y += vy * ts
    if x + w < -20.0 or x > Cfg.SCREEN_W + 100.0 or y > Cfg.SCREEN_H or y + h < -100.0:
        active = false
    elif (kind == "nut" or kind == "virus") and y + h >= Cfg.SOIL_Y:
        active = false  # splat
    sync()
    queue_redraw()


func _draw() -> void:
    var c := Vector2(w / 2.0, h / 2.0)
    match kind:
        "gas":
            var puff := 0.5 + 0.5 * sin(age * 9.0)
            draw_circle(c + Vector2(-8, 2), 11.0 + puff * 2.0, Color(0.55, 0.8, 0.25, 0.55))
            draw_circle(c + Vector2(6, -3), 12.0 - puff * 2.0, Color(0.45, 0.72, 0.2, 0.6))
            draw_circle(c + Vector2(2, 6), 9.0, Color(0.7, 0.9, 0.35, 0.5))
        "nut":
            draw_set_transform_matrix(Transform2D(age * 9.0, c).translated_local(-c))  # spins around its middle
            Shot.draw_acorn(self, w, h, Color8(196, 142, 60), Color8(110, 70, 30))
            draw_set_transform_matrix(Transform2D.IDENTITY)
        "virus":
            var spin := age * 3.0
            var art := virus_art()
            if art != null:
                draw_set_transform_matrix(Transform2D(spin, c).translated_local(-c))
                draw_texture_rect(art, Rect2(0, 0, w, h), false)
                draw_set_transform_matrix(Transform2D.IDENTITY)
            else:
                for k in 8:  # spikes
                    var a := spin + TAU * k / 8.0
                    draw_line(c + Vector2(cos(a), sin(a)) * w * 0.3, c + Vector2(cos(a), sin(a)) * w * 0.5, Color8(110, 40, 150), 3.0)
                draw_circle(c, w * 0.34, Color8(170, 70, 210))
                draw_circle(c, w * 0.14, Color8(235, 190, 250))
        "fire":
            var flick := 0.5 + 0.5 * sin(age * 25.0)
            draw_circle(c, w / 2.0 + flick * 2.0, Color(1.0, 0.45, 0.1, 0.85))
            draw_circle(c, w / 3.0, Color(1.0, 0.85, 0.3))
