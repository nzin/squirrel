class_name Entity
extends Node2D
## Base class for every world object. x/y/w/h are pygame-style top-left pixel
## coordinates; `sync()` copies them to the node position for rendering.

var x := 0.0
var y := 0.0
var w := 0.0
var h := 0.0
var active := true
var sprite: Sprite2D
## Collision box as fractions of the sprite box (left, top, width, height), so
## transparent margins of the art don't count: you land on what you can see.
## The default covers the whole sprite.
var hitbox := Rect2(0.0, 0.0, 1.0, 1.0)


func place(px: float, py: float) -> void:
    x = px
    y = py
    sync()


func sync() -> void:
    position = Vector2(x, y)


## Collision rectangle in screen pixels (the visible part of the sprite).
func rect() -> Rect2:
    return Rect2(x + hitbox.position.x * w, y + hitbox.position.y * h, hitbox.size.x * w, hitbox.size.y * h)


## Horizontal offset of the collision box from `x` (for left-edge "crossing" tests).
func hit_dx() -> float:
    return hitbox.position.x * w


## Show `tex` stretched to this entity's w/h (same distortion as pygame's scale()).
func set_sprite(tex: Texture2D) -> void:
    if sprite == null:
        sprite = Sprite2D.new()
        sprite.centered = false
        add_child(sprite)
    sprite.texture = tex
    sprite.scale = Vector2(w / tex.get_width(), h / tex.get_height())
