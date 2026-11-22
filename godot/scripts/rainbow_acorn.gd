class_name RainbowAcorn
extends Entity
## Bonus pickup that rides on the upper cloud row: +5 acorns, +2 points.
## When collected it floats to the top of the screen and fades out over 2 s.

const ANIM_DURATION := 2.0

var collected := false
var anim_elapsed := 0.0
var anim_start_y := 0.0


func _init() -> void:
    w = 30.0
    h = 30.0


func _ready() -> void:
    set_sprite(Cfg.tex("rainbow_acorn.png"))


func collect() -> void:
    if collected:
        return
    collected = true
    anim_elapsed = 0.0
    anim_start_y = y


func update(scroll_speed: float, delta: float) -> void:
    if not collected:
        x -= scroll_speed
        if x + w < 0.0:
            active = false
    else:
        anim_elapsed += delta
        if anim_elapsed < ANIM_DURATION:
            var progress := anim_elapsed / ANIM_DURATION
            y = anim_start_y - anim_start_y * progress
            x -= scroll_speed
            modulate.a = 1.0 - progress
        else:
            active = false
    sync()
