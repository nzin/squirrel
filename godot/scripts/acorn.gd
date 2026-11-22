class_name Acorn
extends Entity
## Thrown projectile: flies straight right at 10 px/tick, no gravity.

const SPEED := 10.0
const BODY := Color8(139, 90, 43)
const CAP := Color8(101, 67, 33)


func _init() -> void:
    w = 15.0
    h = 20.0


func update() -> void:
    x += SPEED
    if x > Cfg.SCREEN_W:
        active = false
    sync()


func _draw() -> void:
    Acorn.draw_shape(self, w, h)


## Shared by thrown acorns and the PopupAcorn that flies out of boxes.
static func draw_shape(ci: CanvasItem, aw: float, ah: float) -> void:
    var pts := PackedVector2Array()
    for i in 24:
        var a := TAU * i / 24.0
        pts.append(Vector2(aw / 2.0 + cos(a) * aw / 2.0, ah / 2.0 + sin(a) * ah / 2.0))
    ci.draw_colored_polygon(pts, BODY)
    ci.draw_arc(Vector2(aw / 2.0, ah / 4.0), (aw + 4.0) / 2.0, PI, TAU, 16, CAP, 3.0)
