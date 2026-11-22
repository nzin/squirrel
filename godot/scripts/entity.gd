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


func place(px: float, py: float) -> void:
    x = px
    y = py
    sync()


func sync() -> void:
    position = Vector2(x, y)


func rect() -> Rect2:
    return Rect2(x, y, w, h)


## Show `tex` stretched to this entity's w/h (same distortion as pygame's scale()).
func set_sprite(tex: Texture2D) -> void:
    if sprite == null:
        sprite = Sprite2D.new()
        sprite.centered = false
        add_child(sprite)
    sprite.texture = tex
    sprite.scale = Vector2(w / tex.get_width(), h / tex.get_height())
