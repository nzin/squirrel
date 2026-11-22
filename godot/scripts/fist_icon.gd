class_name FistIcon
extends Control
## A small clenched fist, drawn in code (HUD / shop).

func _init(diameter := 28.0) -> void:
    custom_minimum_size = Vector2(diameter, diameter)
    size = Vector2(diameter, diameter)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var s := size.x
    var skin := Color8(245, 195, 140)
    var edge := Color8(150, 90, 50)
    draw_rect(Rect2(s * 0.28, s * 0.78, s * 0.46, s * 0.2), Color8(60, 90, 160))        # sleeve
    draw_rect(Rect2(s * 0.12, s * 0.32, s * 0.74, s * 0.5), skin)                        # palm
    for i in 4:                                                                          # knuckles
        var c := Vector2(s * (0.2 + 0.19 * i), s * 0.3)
        draw_circle(c, s * 0.11, skin)
        draw_arc(c, s * 0.11, PI, TAU, 8, edge, 1.5)
        draw_line(Vector2(c.x, s * 0.4), Vector2(c.x, s * 0.55), edge, 1.2)              # finger gaps
    draw_circle(Vector2(s * 0.16, s * 0.62), s * 0.13, skin)                             # thumb
    draw_arc(Vector2(s * 0.16, s * 0.62), s * 0.13, 0.5 * PI, 1.5 * PI, 8, edge, 1.5)
    draw_rect(Rect2(s * 0.12, s * 0.32, s * 0.74, s * 0.5), edge, false, 1.5)
