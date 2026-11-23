class_name ChestnutIcon
extends Control
## A small chestnut, drawn in code (HUD).

func _init(diameter := 26.0) -> void:
    custom_minimum_size = Vector2(diameter, diameter)
    size = Vector2(diameter, diameter)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var c := size / 2.0 + Vector2(0.0, size.y * 0.06)
    var r := size.x * 0.42
    draw_circle(c, r, Color8(110, 60, 30))
    draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color8(165, 105, 62))
    draw_arc(c, r, 0.0, TAU, 20, Color8(60, 30, 14), 1.5)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.95), c + Vector2(0.0, -r * 1.35), c + Vector2(r * 0.35, -r * 0.95)]), Color8(60, 90, 40))
