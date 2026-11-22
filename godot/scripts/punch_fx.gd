class_name PunchFx
extends Node2D
## Impact effect of the Matrix Fist: a fist and an expanding shockwave ring.

const LIFETIME := 0.6

var _age := 0.0


func tick(real_delta: float) -> bool:
    _age += real_delta
    queue_redraw()
    return _age < LIFETIME


func _draw() -> void:
    var t := clampf(_age / LIFETIME, 0.0, 1.0)
    draw_arc(Vector2.ZERO, 14.0 + 90.0 * t, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 1.0 - t), 5.0 * (1.0 - t) + 1.0)
    draw_arc(Vector2.ZERO, 8.0 + 55.0 * t, 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 1.0 - t), 3.0)
    for i in 8:  # impact sparks
        var a := TAU * i / 8.0
        draw_line(Vector2(cos(a), sin(a)) * (10.0 + 30.0 * t), Vector2(cos(a), sin(a)) * (20.0 + 55.0 * t), Color(1.0, 0.95, 0.6, 1.0 - t), 3.0)
