class_name Box
extends Entity
## "?" block. Bump it from below to collect 1-3 acorns.

const BOX_COLOR := Color8(200, 150, 100)
const BORDER_COLOR := Color8(101, 67, 33)

var collected := false
var should_collect := false  # set by Squirrel.update when hit from below


func _init() -> void:
    w = 40.0
    h = 40.0


func update(scroll_speed: float) -> void:
    x -= scroll_speed
    if x + w < 0.0:
        active = false
    sync()


func mark_collected() -> void:
    collected = true
    queue_redraw()


func _draw() -> void:
    var body := Color8(150, 150, 150) if collected else BOX_COLOR
    draw_rect(Rect2(0, 0, w, h), body)
    draw_rect(Rect2(0, 0, w, h), BORDER_COLOR, false, 2.0)
    if collected:
        draw_polyline(
            PackedVector2Array([Vector2(10, 21), Vector2(17, 29), Vector2(30, 12)]),
            Color.BLACK, 3.0
        )
    else:
        var font := ThemeDB.fallback_font
        draw_string(font, Vector2(0, h / 2.0 + 8.0), "?", HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color.BLACK)
