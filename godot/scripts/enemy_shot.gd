class_name EnemyShot
extends Entity
## A projectile fired by an enemy. Lethal on any contact with the squirrel
## (unlike enemies, which only hurt on a head-on crossing); the player's
## acorns destroy it, and so does the Matrix Fist.
##   gas   skunk: a slow stink cloud rolling along the ground - jump over it
##   egg   bird: dropped, falls under gravity
##   fire  ptero / boss: a fireball aimed at the squirrel
##   nut   raccoon: thrown in a horizontal straight line from its front paws (jump over it)

const EGG_G := 0.35
const SPECS := {
    "gas":  {"w": 36.0, "h": 28.0, "speed": 4.2, "gravity": 0.0},
    "egg":  {"w": 16.0, "h": 20.0, "speed": 3.5, "gravity": EGG_G},
    "fire": {"w": 26.0, "h": 26.0, "speed": 6.0, "gravity": 0.0},
    "nut":  {"w": 18.0, "h": 20.0, "speed": 7.0, "gravity": 0.0},  # thrown in a straight horizontal line
}

var kind := "gas"
var vx := 0.0
var vy := 0.0
var gravity := 0.0
var age := 0.0


## `aim` = unit direction (only used by "fire"); other kinds have a fixed path.
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
    elif kind == "nut":  # straight and level, in front of the thrower, like the gas cloud
        vx = -speed
    else:
        vx = -speed
    place(px - w / 2.0, py - h / 2.0)


func update(delta: float) -> void:
    var ts := Cfg.time_scale
    age += delta
    vy += gravity * ts
    x += vx * ts
    y += vy * ts
    if x + w < -20.0 or x > Cfg.SCREEN_W + 100.0 or y > Cfg.SCREEN_H or y + h < -100.0:
        active = false
    elif (kind == "egg" or kind == "nut") and y + h >= Cfg.SOIL_Y:
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
        "egg":
            Shot.fill_ellipse(self, c, w / 2.0, h / 2.0, Color8(245, 235, 200))
            draw_arc(c, w / 2.0, 0.0, TAU, 16, Color8(150, 130, 90), 1.5)
        "fire":
            var flick := 0.5 + 0.5 * sin(age * 25.0)
            draw_circle(c, w / 2.0 + flick * 2.0, Color(1.0, 0.45, 0.1, 0.85))
            draw_circle(c, w / 3.0, Color(1.0, 0.85, 0.3))
