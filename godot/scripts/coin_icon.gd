class_name CoinIcon
extends Control
## A small gold coin, drawn in code (no asset needed).

func _init(diameter := 24.0) -> void:
    custom_minimum_size = Vector2(diameter, diameter)
    size = Vector2(diameter, diameter)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var c := size / 2.0
    var r := minf(size.x, size.y) / 2.0
    draw_circle(c, r, Color8(184, 134, 11))          # dark gold rim
    draw_circle(c, r * 0.82, Color8(255, 205, 40))   # gold face
    draw_arc(c, r * 0.58, 0.0, TAU, 24, Color8(214, 160, 20), maxf(1.5, r * 0.14))  # inner ring
    draw_arc(c, r * 0.68, PI * 1.05, PI * 1.55, 8, Color8(255, 240, 160), maxf(1.5, r * 0.16))  # shine
