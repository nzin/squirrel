class_name Squirrel
extends Entity
## The player. Physics is a direct port of the pygame Squirrel.update():
##  - boxes are solid: hit from below = collect, land on top, hit from the side = death
##  - clouds, tree tops and enemies are one-way platforms: pass through going up, land when falling

const START_X := 50.0
const LAND_TOLERANCE := 1.0  # px: how far below a platform top the feet may start and still land on it

var velocity_y := 0.0
var is_jumping := false
var ground_y := 0.0
var prev_x := 0.0
var prev_y := 0.0
var game_over := false
var diver := false  # drawn as the diver (Diver Armor run, art installed)
var _anim := 0.0
var armor_frac := 1.0:  # Diver Armor health (1 = full): drawn as a small bar over the diver
    set(v):
        armor_frac = v
        queue_redraw()
var hurt_flash := 0.0   # physics ticks left of the red tint after a hit

const DIVER_FRAMES := ["res://private/diver_1.png", "res://private/diver_2.png", "res://private/diver_3.png",
    "res://private/diver_4.png", "res://private/diver_5.png"]
const HURT_FLASH_TICKS := 8.0
const DIVER_FRAME_TICKS := 7.0  # physics ticks per walk-cycle frame
const DIVER_HEIGHT := 68.0      # drawn height (the physics box stays 40x40)
const DIVER_SHIFT_X := 12.0     # the art's gun sticks out to the right: nudge it so the body sits on the box
const DIVER_MUZZLE := 30.0      # how much further right than the box the harpoon leaves
const DIVER_MUZZLE_RISE := 20.0 # ...and how much higher: the gun is held above the middle
static var _diver_art: Array[Texture2D] = []
static var _diver_checked := false


func _init() -> void:
    w = 40.0
    h = 40.0
    ground_y = Cfg.SOIL_Y - h


func _ready() -> void:
    set_sprite(Cfg.tex("squirrel.png"))
    sprite.centered = true  # rotate around the middle on game over
    sprite.position = Vector2(w / 2.0, h / 2.0)
    reset()


## The optional Diver Armor frames (walk cycle), or [] when the local art is absent
## (godot/private/, see CREDITS.md): the squirrel sprite is then kept.
static func diver_art() -> Array[Texture2D]:
    if not _diver_checked:
        _diver_checked = true
        var frames: Array[Texture2D] = []
        for f: String in DIVER_FRAMES:
            if not ResourceLoader.exists(f):
                frames.clear()
                break
            frames.append(load(f))
        _diver_art = frames
    return _diver_art


## Wear (or take off) the Diver Armor. The 40x40 physics box never changes (landing and
## collisions behave as before); only the picture gets bigger, standing on the box's bottom.
func set_diver(on: bool) -> void:
    diver = on and not diver_art().is_empty()
    _anim = 0.0
    _show_frame()
    queue_redraw()


## A hit on the armor: tint the sprite red for a few ticks.
func flash_hurt() -> void:
    hurt_flash = HURT_FLASH_TICKS


func _draw() -> void:
    if not diver:
        return
    var bar_w := 40.0
    var top := h - DIVER_HEIGHT - 9.0
    draw_rect(Rect2(0.0, top, bar_w, 5.0), Color(0, 0, 0, 0.6))
    var f := clampf(armor_frac, 0.0, 1.0)
    draw_rect(Rect2(1.0, top + 1.0, (bar_w - 2.0) * f, 3.0), Color(1.0 - f, 0.4 + 0.5 * f, 0.15))


func _show_frame() -> void:
    if sprite == null:
        return
    if not diver:
        var tex := Cfg.tex("squirrel.png")
        sprite.texture = tex
        sprite.scale = Vector2(w / tex.get_width(), h / tex.get_height())
        sprite.position = Vector2(w / 2.0, h / 2.0)
        return
    var art := diver_art()
    var frame_tex: Texture2D = art[int(_anim / DIVER_FRAME_TICKS) % art.size()]
    sprite.texture = frame_tex
    var s := DIVER_HEIGHT / frame_tex.get_height()
    sprite.scale = Vector2(s, s)
    # horizontally on the box, feet on its bottom edge
    sprite.position = Vector2(w / 2.0 + DIVER_SHIFT_X, h - DIVER_HEIGHT / 2.0)


## y where a shot leaves the player (the vertical middle; the gun's height for the diver).
func muzzle_y() -> float:
    return y + int(h / 2.0) - (DIVER_MUZZLE_RISE if diver else 0.0)


## x where a shot leaves the player (the gun's muzzle for the diver).
func muzzle_x() -> float:
    return x + w + (DIVER_MUZZLE if diver else 0.0)


func reset() -> void:
    x = START_X
    y = ground_y
    prev_x = x
    prev_y = y
    velocity_y = 0.0
    is_jumping = false
    game_over = false
    if sprite:
        sprite.rotation = 0.0
    sync()


## True when the squirrel's feet rest on top of any of `items` (boxes/clouds).
func stands_on(items: Array) -> bool:
    var bottom := y + h
    for it: Entity in items:
        if not it.active:
            continue
        var r := it.rect()
        if absf(bottom - r.position.y) < 5.0 and x < r.end.x and x + w > r.position.x:
            return true
    return false


func jump(boxes: Array, clouds: Array) -> void:
    if game_over:
        return
    var on_ground := y >= ground_y - 1.0
    if (on_ground or stands_on(boxes) or stands_on(clouds)) and velocity_y >= 0.0:
        velocity_y = Cfg.JUMP_STRENGTH
        is_jumping = true


func update(boxes: Array, clouds: Array) -> void:
    prev_y = y
    prev_x = x

    # No gravity while resting on a platform
    var on_platform := false
    if velocity_y >= 0.0:
        on_platform = stands_on(clouds) or stands_on(boxes)
    var ts := Cfg.time_scale
    if not on_platform:
        velocity_y += Cfg.GRAVITY * ts

    var new_y := y + velocity_y * ts

    # --- boxes (solid) ---
    var sq := Rect2(x, new_y, w, h)
    for b: Entity in boxes:
        if not b.active:
            continue
        var br := b.rect()
        if not br.intersects(sq):
            continue
        var prev_bottom := prev_y + h
        var box_top := br.position.y
        var box_bottom := br.end.y
        if prev_bottom >= box_top and velocity_y < 0.0:
            # jumping into the box from below
            if new_y <= box_bottom:
                (b as Box).should_collect = true
                new_y = box_bottom
                velocity_y = 0.0
        elif prev_y <= box_top and velocity_y > 0.0:
            # landing on top
            new_y = box_top - h
            velocity_y = 0.0
            is_jumping = false
        else:
            game_over = true

    # --- clouds (one-way: only when falling / at the apex) ---
    if velocity_y >= 0.0:
        sq = Rect2(x, new_y, w, h)
        for c: Entity in clouds:
            if not c.active:
                continue
            var cr := c.rect()
            # land only when the FEET were at or above the top last tick. (Comparing the
            # head with the top let a squirrel falling past a cloud's side get snapped up
            # onto the next cloud as it scrolled in.)
            if cr.intersects(sq) and prev_y + h <= cr.position.y + LAND_TOLERANCE:
                new_y = cr.position.y - h
                velocity_y = 0.0
                is_jumping = false
                break

    y = new_y

    # --- stay glued to whatever we are standing on ---
    var standing_on_box := false
    for b: Entity in boxes:
        if not b.active:
            continue
        var br2 := b.rect()
        if absf((y + h) - br2.position.y) < 5.0 and x < br2.end.x and x + w > br2.position.x:
            standing_on_box = true
            y = br2.position.y - h
            velocity_y = 0.0
            is_jumping = false
            break

    var standing_on_cloud := false
    if velocity_y >= 0.0:
        for c: Entity in clouds:
            if not c.active:
                continue
            var cr2 := c.rect()
            if absf((y + h) - cr2.position.y) < 5.0 and x < cr2.end.x and x + w > cr2.position.x:
                standing_on_cloud = true
                var target_y := cr2.position.y - h
                if absf(y - target_y) > 1.0:
                    y = target_y
                velocity_y = 0.0
                is_jumping = false
                break

    if not standing_on_box and not standing_on_cloud and y >= ground_y:
        y = ground_y
        velocity_y = 0.0
        is_jumping = false

    sprite.rotation = -PI / 2.0 if game_over else 0.0  # lies on its side
    if diver:
        _anim += Cfg.time_scale
        _show_frame()
    if hurt_flash > 0.0:
        hurt_flash -= Cfg.time_scale
    var tint := Color(1.0, 0.35, 0.35) if hurt_flash > 0.0 else Color.WHITE
    sprite.modulate = Color(tint.r, tint.g, tint.b, sprite.modulate.a)  # (alpha belongs to the blinking)
    sync()
