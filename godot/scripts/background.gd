class_name Background
extends Node2D
## Two horizontally tiling strips: sky above the soil line, ground below.
## Both scroll at the world speed (driven by Game.scroll_offset).

var up_tex: Texture2D = Cfg.tex("background-up.jpg")
var down_tex: Texture2D = Cfg.tex("background-down.jpg")
var up_w := 0.0
var down_w := 0.0
var scroll := 0.0


func _ready() -> void:
    up_w = float(int(up_tex.get_width() * (float(Cfg.SOIL_Y) / up_tex.get_height())))
    down_w = float(int(down_tex.get_width() * (float(Cfg.SOIL_HEIGHT) / down_tex.get_height())))


func set_scroll(value: float) -> void:
    scroll = value
    queue_redraw()


func _draw() -> void:
    var up_off := fmod(scroll, up_w)
    var down_off := fmod(scroll, down_w)
    for i in range(-1, 3):
        draw_texture_rect(up_tex, Rect2(i * up_w - up_off, 0, up_w, Cfg.SOIL_Y), false)
        draw_texture_rect(down_tex, Rect2(i * down_w - down_off, Cfg.SOIL_Y, down_w, Cfg.SOIL_HEIGHT), false)
