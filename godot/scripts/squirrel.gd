class_name Squirrel
extends Entity
## The player. Physics is a direct port of the pygame Squirrel.update():
##  - boxes are solid: hit from below = collect, land on top, hit from the side = death
##  - clouds and tree tops are one-way platforms: pass through going up, land when falling

const START_X := 50.0

var velocity_y := 0.0
var is_jumping := false
var ground_y := 0.0
var prev_x := 0.0
var prev_y := 0.0
var game_over := false


func _init() -> void:
    w = 40.0
    h = 40.0
    ground_y = Cfg.SOIL_Y - h


func _ready() -> void:
    set_sprite(Cfg.tex("squirrel.png"))
    sprite.centered = true  # rotate around the middle on game over
    sprite.position = Vector2(w / 2.0, h / 2.0)
    reset()


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
    if not on_platform:
        velocity_y += Cfg.GRAVITY

    var new_y := y + velocity_y

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
            if cr.intersects(sq) and prev_y <= cr.position.y:
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
    sync()
