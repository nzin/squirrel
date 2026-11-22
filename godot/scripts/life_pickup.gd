class_name LifePickup
extends Entity
## "1UP": a floating heart riding on the top cloud row. Collect it for an
## extra life (max Weapons.MAX_LIVES; at the maximum it pays coins instead).

var _t := 0.0
var _base_y := 0.0


func _init() -> void:
    w = 34.0
    h = 32.0


func place_on(px: float, py: float) -> void:
    place(px, py)
    _base_y = py


func update(scroll_speed: float, delta: float) -> void:
    _t += delta
    x -= scroll_speed
    y = _base_y + 4.0 * sin(_t * 4.0)
    if x + w < 0.0:
        active = false
    sync()


func _draw() -> void:
    var pulse := 1.0 + 0.06 * sin(_t * 8.0)
    var c := Vector2(w / 2.0, h / 2.0 + 1.0)
    draw_circle(c, 17.0 * pulse, Color(1.0, 0.9, 0.5, 0.35))  # glow
    var red := Color8(225, 40, 70)
    draw_circle(c + Vector2(-6.5, -4.0), 7.5, red)
    draw_circle(c + Vector2(6.5, -4.0), 7.5, red)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-13.5, -1.0), c + Vector2(13.5, -1.0), c + Vector2(0.0, 13.0)]), red)
    draw_circle(c + Vector2(-8.0, -6.5), 2.5, Color(1, 1, 1, 0.7))  # shine
    draw_string(ThemeDB.fallback_font, Vector2(0, h + 11.0), "1UP", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color.WHITE)
