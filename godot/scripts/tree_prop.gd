class_name TreeProp
extends Entity
## Ground obstacle: unkillable, lethal on a left-side hit.
## (Named TreeProp because `Tree` is a built-in Godot UI class.)


func _init() -> void:
    w = 60.0
    h = 75.0


func _ready() -> void:
    set_sprite(Cfg.tex("tree%d.png" % randi_range(1, 2)))


var prev_x := 0.0


func update(scroll_speed: float) -> void:
    prev_x = x
    x -= scroll_speed
    if x + w < 0.0:
        active = false
    sync()
