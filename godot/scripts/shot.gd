class_name Shot
extends Entity
## A thrown projectile. One class for every weapon (see Weapons): `kind` picks
## the size, speed and flight behaviour. Collision with enemies is resolved by
## Game._update_shots; the shot itself only moves and draws.
##   acorn      straight, consumed on hit (also used by the triple-acorn fan)
##   boomerang  flies out, returns; pierces, each enemy hit once per leg
##   chestnut   arcs, bounces along the ground, explodes on contact or its 3rd bounce
##   pinecone   slow lob; detonates on contact/ground, area damage
##   harpoon    thrown by the Diver Armor: flies like a plain acorn
##   homing     steers toward the nearest enemy ahead

const BODY := Color8(139, 90, 43)
const CAP := Color8(101, 67, 33)
## Optional licensed harpoon picture (head + a short rod), local-only like the explosions.
const HARPOON_ART := "res://private/diver_harpoon.png"
const HARPOON_HEAD_W := 27.0  # drawn width of that picture (the rod is drawn behind it)
const STEEL := Color8(150, 175, 185)
const STEEL_DARK := Color8(25, 25, 30)
static var _harpoon_art: Texture2D = null
static var _harpoon_checked := false
const BLAST_TICKS := 14
const CHESTNUT_BOUNCES := 3       # it explodes on the third bounce
const CHESTNUT_BLAST_TICKS := 22  # a longer explosion: it plays a 9-frame animation
## Optional licensed explosion frames, kept out of the public repo (godot/private/,
## see CREDITS.md). Without them the chestnut explodes with the plain orange burst.
const EXPLOSION_FRAMES := ["res://private/explosion_1.png", "res://private/explosion_2.png", "res://private/explosion_3.png",
    "res://private/explosion_4.png", "res://private/explosion_5.png", "res://private/explosion_6.png",
    "res://private/explosion_7.png", "res://private/explosion_8.png", "res://private/explosion_9.png"]
const EXPLOSION_SIZE_PER_RADIUS := 3.4  # drawn size of a frame = blast radius x this
## The pinecone's explosion (and the chestnut's when its own frames are missing): a 10-frame
## mushroom cloud, also licensed and local-only.
const MUSHROOM_FRAMES := ["res://private/mushroom_1.png", "res://private/mushroom_2.png", "res://private/mushroom_3.png",
    "res://private/mushroom_4.png", "res://private/mushroom_5.png", "res://private/mushroom_6.png",
    "res://private/mushroom_7.png", "res://private/mushroom_8.png", "res://private/mushroom_9.png",
    "res://private/mushroom_10.png"]
const MUSHROOM_BLAST_TICKS := 26
const MUSHROOM_SIZE_PER_RADIUS := 3.2  # drawn width of a frame = blast radius x this
## The pinecone's explosion when it LANDS: a 9-frame burst that spreads along the ground.
const GROUND_FRAMES := ["res://private/groundburst_1.png", "res://private/groundburst_2.png", "res://private/groundburst_3.png",
    "res://private/groundburst_4.png", "res://private/groundburst_5.png", "res://private/groundburst_6.png",
    "res://private/groundburst_7.png", "res://private/groundburst_8.png", "res://private/groundburst_9.png"]
const GROUND_BLAST_TICKS := 24
const GROUND_SIZE_PER_RADIUS := 3.8
static var _ground_art: Array[Texture2D] = []
static var _ground_checked := false
static var _mushroom_art: Array[Texture2D] = []
static var _mushroom_checked := false
static var _explosion_art: Array[Texture2D] = []
static var _explosion_checked := false
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
var bounced := false  # set when a chestnut bounces (Game plays the sound)

var exploding := false
var exploded := false
var blast_age := 0.0
var blast_radius := 0.0
var blast_ticks := float(BLAST_TICKS)
var burst := "ring"  # which explosion animation plays: chestnut | ground | mushroom | ring
var bounce_count := 0


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
            damage = 2           # the explosion deals 2 damage...
            blast_radius = 75.0  # ...to every opponent close by (within 75 px), not just the one it touched
        "pinecone":
            w = 22.0
            h = 28.0
            vx = 6.0
            vy = -4.0
            gravity = 0.25
            damage = 2
            blast_radius = 100.0
        "harpoon":
            w = 42.0
            h = 24.0
        "homing":
            w = 15.0
            h = 20.0
            vx = HOMING_SPEED
    if blast_radius > 0.0:  # an explosive: its blast lasts as long as its animation
        blast_ticks = _ticks_for(_choose_burst(false))
    place(px, py + 10.0 - h / 2.0)  # a 20 px acorn keeps its original spawn point
    origin_x = x


## A purely visual explosion (no damage: `exploded` is already set so Game never blasts),
## centred on `at`, with the chestnut's animation scaled to `radius`.
static func create_blast(at: Vector2, radius: float) -> Shot:
    var s := Shot.create("chestnut", at.x, at.y)
    s.place(at.x - s.w / 2.0, at.y - s.h / 2.0)
    s.damage = 0
    s.blast_radius = radius
    s.exploded = true
    s.detonate()
    return s


## The optional harpoon picture, or null when the local art is absent.
static func harpoon_art() -> Texture2D:
    if not _harpoon_checked:
        _harpoon_checked = true
        if ResourceLoader.exists(HARPOON_ART):
            _harpoon_art = load(HARPOON_ART)
    return _harpoon_art


## The optional ground-burst frames, or [] when the local art is absent.
static func ground_art() -> Array[Texture2D]:
    if not _ground_checked:
        _ground_checked = true
        var frames: Array[Texture2D] = []
        for f: String in GROUND_FRAMES:
            if not ResourceLoader.exists(f):
                frames.clear()
                break
            frames.append(load(f))
        _ground_art = frames
    return _ground_art


## The optional mushroom-cloud frames, or [] when the local art is absent.
static func mushroom_art() -> Array[Texture2D]:
    if not _mushroom_checked:
        _mushroom_checked = true
        var frames: Array[Texture2D] = []
        for f: String in MUSHROOM_FRAMES:
            if not ResourceLoader.exists(f):
                frames.clear()
                break
            frames.append(load(f))
        _mushroom_art = frames
    return _mushroom_art


## The optional explosion animation frames, or [] when the local art is absent.
static func explosion_art() -> Array[Texture2D]:
    if not _explosion_checked:
        _explosion_checked = true
        var frames: Array[Texture2D] = []
        for f: String in EXPLOSION_FRAMES:
            if not ResourceLoader.exists(f):
                frames.clear()
                break
            frames.append(load(f))
        _explosion_art = frames
    return _explosion_art


## Which animation an explosion plays: the chestnut has its own; otherwise a blast on
## the ground spreads along it, and one in the air (a hit) is a rising mushroom cloud.
## Without any installed art it is just a ring.
func _choose_burst(on_ground: bool) -> String:
    if kind == "chestnut" and not explosion_art().is_empty():
        return "chestnut"
    if on_ground and not ground_art().is_empty():
        return "ground"
    if not mushroom_art().is_empty():
        return "mushroom"
    return "ring"


func _ticks_for(style: String) -> float:
    match style:
        "chestnut":
            return float(CHESTNUT_BLAST_TICKS)
        "ground":
            return float(GROUND_BLAST_TICKS)
        "mushroom":
            return float(MUSHROOM_BLAST_TICKS)
    return float(BLAST_TICKS)


func detonate(on_ground := false) -> void:
    if exploding:
        return
    exploding = true
    blast_age = 0
    burst = _choose_burst(on_ground)
    blast_ticks = _ticks_for(burst)
    queue_redraw()


func blast_center() -> Vector2:
    return rect().get_center()


## One physics tick. `enemies` is only read by the homing shot.
func update(sq: Squirrel, enemies: Array) -> void:
    var ts := Cfg.time_scale
    if exploding:
        blast_age += ts
        if blast_age > blast_ticks:
            active = false
        queue_redraw()
        return

    match kind:
        "boomerang":
            if not returning and x - origin_x >= BOOMERANG_RANGE:
                returning = true
                vx = -vx
                hit_ids.clear()  # may hit everything again on the way back
            spin += 0.45 * ts
            queue_redraw()
        "homing":
            _steer(enemies)

    vy += gravity * ts
    x += vx * ts
    y += vy * ts

    if gravity > 0.0 and y + h >= Cfg.SOIL_Y:
        y = Cfg.SOIL_Y - h
        if kind == "pinecone":
            detonate(true)
        else:
            bounce_count += 1
            bounced = true
            if bounce_count >= CHESTNUT_BOUNCES:
                detonate(true)  # ...and blows up on the third bounce
            else:
                vy = -7.0

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
    var v := Vector2(vx, vy).lerp(want, 0.2 * Cfg.time_scale)
    vx = v.x
    vy = v.y


## Only used when no explosion art is installed at all: a plain expanding ring, so the
## blast is at least visible. (The cartoon explosions live in godot/private/.)
func _draw_ring_flash(c: Vector2, t: float) -> void:
    draw_arc(c, blast_radius * (0.3 + 0.7 * t), 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - t)), 4.0)


func _draw() -> void:
    var c := Vector2(w / 2.0, h / 2.0)
    if exploding:
        var t := clampf(blast_age / blast_ticks, 0.0, 1.0)
        match burst:
            "chestnut":  # centred on the shot
                var art := explosion_art()
                var tex: Texture2D = art[mini(art.size() - 1, int(t * art.size()))]
                var side := blast_radius * EXPLOSION_SIZE_PER_RADIUS
                draw_texture_rect(tex, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false)
                return
            "ground":  # rooted on the ground line (the shot's bottom), wide
                var gnd := ground_art()
                var gtex: Texture2D = gnd[mini(gnd.size() - 1, int(t * gnd.size()))]
                var gw := blast_radius * GROUND_SIZE_PER_RADIUS
                var gh := gw * gtex.get_height() / gtex.get_width()
                draw_texture_rect(gtex, Rect2(c.x - gw / 2.0, h - gh, gw, gh), false)
                return
            "mushroom":  # rising from the ground line
                var cloud := mushroom_art()
                var ctex: Texture2D = cloud[mini(cloud.size() - 1, int(t * cloud.size()))]
                var width := blast_radius * MUSHROOM_SIZE_PER_RADIUS
                var height := width * ctex.get_height() / ctex.get_width()
                draw_texture_rect(ctex, Rect2(c.x - width / 2.0, h - height, width, height), false)
                return
        _draw_ring_flash(c, t)
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
        "harpoon":
            _draw_harpoon()
        "boomerang":
            draw_set_transform(c, spin)
            draw_arc(Vector2.ZERO, 10.0, PI * 0.2, PI * 1.3, 14, Color8(215, 165, 70), 6.0)
            draw_set_transform(Vector2.ZERO, 0.0)


## A steel rod ending in an arrowhead: the diver's picture when installed, else a drawn one.
func _draw_harpoon() -> void:
    var mid := h / 2.0
    var art := harpoon_art()
    var head_w := HARPOON_HEAD_W if art != null else 14.0
    draw_rect(Rect2(0, mid - 1.5, w - head_w + 2.0, 3.0), STEEL_DARK)
    draw_rect(Rect2(0, mid - 0.5, w - head_w + 2.0, 1.5), STEEL)
    if art != null:
        draw_texture_rect(art, Rect2(w - head_w, 0, head_w, h), false)
    else:
        var tip := PackedVector2Array([Vector2(w, mid), Vector2(w - head_w, 0), Vector2(w - head_w + 4.0, mid), Vector2(w - head_w, h)])
        draw_colored_polygon(tip, STEEL)
        draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[3], tip[0]]), STEEL_DARK, 2.0)


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
