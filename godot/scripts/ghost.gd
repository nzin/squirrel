class_name Ghost
extends Sprite2D
## One frame of the Matrix Fist's afterimage trail: a blue-tinted copy of the
## squirrel that fades out in real time (not slow-motion time).

const LIFETIME := 0.35

var _age := 0.0


static func create(tex: Texture2D, px: float, py: float, w: float, h: float) -> Ghost:
    var g := Ghost.new()
    g.texture = tex
    g.centered = false
    g.scale = Vector2(w / tex.get_width(), h / tex.get_height())
    g.position = Vector2(px, py)
    g.modulate = Color(0.45, 0.75, 1.0, 0.6)
    return g


## `real_delta` is unscaled time so trails fade at the same speed in slow-mo.
func tick(real_delta: float) -> bool:
    _age += real_delta
    modulate.a = 0.6 * (1.0 - _age / LIFETIME)
    return _age < LIFETIME
