class_name Cloud
extends Entity
## One-way platform. Two endless rows of these are kept scrolling (Game._maintain_clouds).

const CLOUD_HEIGHT := 50.0
const IMAGES := ["cloud1.png", "cloud2.png", "cloud3.png", "cloud4.png"]


func setup(px: float, py: float) -> void:
    var tex := Cfg.tex(IMAGES[randi() % IMAGES.size()])
    h = CLOUD_HEIGHT
    w = float(int(tex.get_width() * (CLOUD_HEIGHT / tex.get_height())))
    set_sprite(tex)
    place(px, py)


func update(scroll_speed: float) -> void:
    x -= scroll_speed
    if x + w < 0.0:
        active = false
    sync()
