class_name Shot
extends Entity
## A thrown projectile. One class for every weapon (see Weapons): `kind` picks
## the size, speed and flight behaviour. Collision with enemies is resolved by
## Game._update_shots; the shot itself only moves and draws.
##   acorn      straight, consumed on hit (also used by the triple-acorn fan)
##   boomerang  flies out, returns; pierces, each enemy hit once per leg
##   chestnut   arcs and bounces along the ground
##   pinecone   slow lob; detonates on contact/ground, area damage
##   rainbow    fast pierce, 2 damage
##   homing     steers toward the nearest enemy ahead

const BODY := Color8(139, 90, 43)
const CAP := Color8(101, 67, 33)
const RAINBOW := [Color8(230, 40, 40), Color8(250, 140, 30), Color8(250, 220, 40),
    Color8(60, 190, 70), Color8(50, 120, 230), Color8(150, 70, 200)]
const BLAST_TICKS := 14
const BOOMERANG_RANGE := 320.0
const HOMING_SPEED := 8.0

var kind := "acorn"
var vx := 10.0
var vy := 0.0
var gravity := 0.0
var damage := 1
var pierce := false  # survives hits instead of being consumed
var hit_ids := {}    # enemies already hit by this (piercing) shot / leg
var origin_x := 0.0
var returning := false
var spin := 0.0

var exploding := false
var exploded := false
var blast_age := 0
var blast_radius := 0.0


## `px, py`: where the shot leaves the squirrel (front, vertical middle).
## `dy`: extra vertical speed (used by the triple-acorn fan).
static func create(shot_kind: String, px: float, py: float, dy := 0.0) -> Shot:
    var s := Shot.new()
    s.setup(shot_kind, px, py, dy)
    return s


func setup(shot_kind: String, px: float, py: float, dy: float) -> void:
    kind = shot_kind
    vy = dy
    match kind:
        "acorn":
            w = 15.0
            h = 20.0
        "boomerang":
            w = 26.0
            h = 26.0
            vx = 9.0
            pierce = true
        "chestnut":
            w = 18.0
            h = 18.0
            vx = 7.0
            vy = -5.0
            gravity = 0.45
        "pinecone":
            w = 22.0
            h = 28.0
            vx = 6.0
            vy = -4.0
            gravity = 0.25
            damage = 2
            blast_radius = 100.0
        "rainbow":
            w = 50.0
            h = 12.0
            vx = 14.0
            damage = 2
            pierce = true
        "homing":
            w = 15.0
            h = 20.0
            vx = HOMING_SPEED
    place(px, py + 10.0 - h / 2.0)  # a 20 px acorn keeps its original spawn point
    origin_x = x


func detonate() -> void:
    if exploding:
        return
    exploding = true
    blast_age = 0
    queue_redraw()


func blast_center() -> Vector2:
    return rect().get_center()


## One physics tick. `enemies` is only read by the homing shot.
func update(sq: Squirrel, enemies: Array) -> void:
    if exploding:
        blast_age += 1
        if blast_age > BLAST_TICKS:
            active = false
        queue_redraw()
        return

    match kind:
        "boomerang":
            if not returning and x - origin_x >= BOOMERANG_RANGE:
                returning = true
                vx = -vx
                hit_ids.clear()  # may hit everything again on the way back
            spin += 0.45
            queue_redraw()
        "homing":
            _steer(enemies)

    vy += gravity
    x += vx
    y += vy

    if gravity > 0.0 and y + h >= Cfg.SOIL_Y:
        y = Cfg.SOIL_Y - h
        if kind == "pinecone":
            detonate()
        else:
            vy = -7.0  # chestnut bounces

    if returning and x <= sq.x + sq.w:
        active = false
    if x > Cfg.SCREEN_W or x + w < 0.0 or y > Cfg.SCREEN_H or y + h < -80.0:
        active = false
    sync()


func _steer(enemies: Array) -> void:
    var best: Enemy = null
    var best_d := INF
    var me := rect().get_center()
    for e: Enemy in enemies:
        if not e.hittable() or e.rect().end.x < x:
            continue
        var d := me.distance_to(e.rect().get_center())
        if d < best_d:
            best_d = d
            best = e
    var want := Vector2(HOMING_SPEED, 0.0)
    if best != null:
        want = (best.rect().get_center() - me).normalized() * HOMING_SPEED
    var v := Vector2(vx, vy).lerp(want, 0.2)
    vx = v.x
    vy = v.y


func _draw() -> void:
    var c := Vector2(w / 2.0, h / 2.0)
    if exploding:
        var t := float(blast_age) / BLAST_TICKS
        draw_circle(c, blast_radius * (0.25 + 0.75 * t), Color(1.0, 0.55, 0.1, 0.6 * (1.0 - t)))
        draw_circle(c, blast_radius * 0.5 * t, Color(1.0, 0.9, 0.4, 0.8 * (1.0 - t)))
        return
    match kind:
        "acorn":
            Shot.draw_acorn(self, w, h)
        "homing":
            Shot.draw_acorn(self, w, h, Color8(70, 120, 200), Color8(40, 70, 130))
        "chestnut":
            draw_circle(c, w / 2.0, Color8(110, 60, 30))
            draw_circle(c + Vector2(-3, -3), w / 5.0, Color8(160, 100, 60))
        "pinecone":
            Shot.fill_ellipse(self, c, w / 2.0, h / 2.0, Color8(150, 105, 55))
            for i in 3:
                var ly := h * (0.3 + 0.2 * i)
                draw_line(Vector2(3, ly), Vector2(w - 3, ly), Color8(95, 60, 25), 2.0)
        "rainbow":
            for i in RAINBOW.size():
                draw_rect(Rect2(0, i * h / RAINBOW.size(), w, h / RAINBOW.size() + 0.5), RAINBOW[i])
        "boomerang":
            draw_set_transform(c, spin)
            draw_arc(Vector2.ZERO, 10.0, PI * 0.2, PI * 1.3, 14, Color8(215, 165, 70), 6.0)
            draw_set_transform(Vector2.ZERO, 0.0)


## Shared by thrown acorns and the PopupAcorn that flies out of boxes.
static func draw_acorn(ci: CanvasItem, aw: float, ah: float, body := BODY, cap := CAP) -> void:
    Shot.fill_ellipse(ci, Vector2(aw / 2.0, ah / 2.0), aw / 2.0, ah / 2.0, body)
    ci.draw_arc(Vector2(aw / 2.0, ah / 4.0), (aw + 4.0) / 2.0, PI, TAU, 16, cap, 3.0)


static func fill_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
    var pts := PackedVector2Array()
    for i in 24:
        var a := TAU * i / 24.0
        pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
    ci.draw_colored_polygon(pts, color)
