class_name PopupAcorn
extends Entity
## Cosmetic acorn that pops out of a collected box for 3 seconds
## (pop up fast, hover, sink back), following the box as the world scrolls.

const DURATION := 3.0
const POPUP_DISTANCE := 40.0

var box_x := 0.0
var box_y := 0.0
var box_w := 0.0
var offset_x := 0.0
var elapsed := 0.0


func _init() -> void:
    w = 15.0
    h = 20.0


func start(bx: float, by: float, bw: float, off_x: float) -> void:
    box_x = bx
    box_y = by
    box_w = bw
    offset_x = off_x
    _reposition(0.0)


func update(scroll_speed: float, delta: float) -> void:
    box_x -= scroll_speed
    elapsed += delta
    if elapsed >= DURATION:
        active = false
        return
    _reposition(elapsed / DURATION)


func _reposition(progress: float) -> void:
    x = box_x + int(box_w / 2.0) - int(w / 2.0) + offset_x
    var base_y := box_y - 20.0
    if progress < 0.3:
        y = base_y - POPUP_DISTANCE * (progress / 0.3)
    elif progress < 0.7:
        y = base_y - POPUP_DISTANCE
    else:
        y = base_y - POPUP_DISTANCE * (1.0 - (progress - 0.7) / 0.3)
    sync()


func _draw() -> void:
    Shot.draw_acorn(self, w, h)
