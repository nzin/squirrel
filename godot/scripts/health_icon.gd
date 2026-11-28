class_name HealthIcon
extends Control
## A small first aid kit (white case, red cross, carrying handle), drawn in code (HUD / shop).

func _init(diameter := 26.0) -> void:
    custom_minimum_size = Vector2(diameter, diameter)
    size = Vector2(diameter, diameter)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var s := size.x
    var edge := Color8(90, 20, 20)
    # carrying handle
    draw_rect(Rect2(s * 0.34, s * 0.1, s * 0.32, s * 0.2), Color8(235, 235, 235), false, maxf(1.5, s * 0.07))
    # case
    draw_rect(Rect2(s * 0.06, s * 0.26, s * 0.88, s * 0.66), Color8(250, 250, 250))
    draw_rect(Rect2(s * 0.06, s * 0.26, s * 0.88, s * 0.66), edge, false, maxf(1.5, s * 0.06))
    # red cross
    var cx := s * 0.5
    var cy := s * 0.59
    var arm := s * 0.2
    var thick := s * 0.15
    draw_rect(Rect2(cx - arm, cy - thick / 2.0, arm * 2.0, thick), Color8(215, 30, 35))
    draw_rect(Rect2(cx - thick / 2.0, cy - arm, thick, arm * 2.0), Color8(215, 30, 35))
