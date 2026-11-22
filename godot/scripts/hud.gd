class_name Hud
extends CanvasLayer
## Score / acorn counters, the "GAME OVER" banner and the restart/controls menu.

const MENU_ITEMS := ["Restart", "Show Controls"]
const CONTROLS := [
    "SPACE - Jump",
    "SHIFT - Throw Acorn",
    "",
    "Collect boxes for acorns!",
    "Avoid trees, skunks, and birds!",
    "Hit enemies with acorns to score!",
]

var score_label: Label
var acorn_label: Label
var banner: Label
var overlay: ColorRect
var menu_root: Control
var _menu_signature := ""


func _ready() -> void:
    score_label = _label("", 30, Color.BLACK, 10, 10, HORIZONTAL_ALIGNMENT_LEFT, 300)
    acorn_label = _label("", 30, Color.BLACK, Cfg.SCREEN_W - 310, 10, HORIZONTAL_ALIGNMENT_RIGHT, 300)
    add_child(score_label)
    add_child(acorn_label)

    banner = _centered("GAME OVER", 64, Color.RED, Cfg.SCREEN_H / 2)
    banner.visible = false
    add_child(banner)

    overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 200.0 / 255.0)
    overlay.size = Vector2(Cfg.SCREEN_W, Cfg.SCREEN_H)
    overlay.visible = false
    add_child(overlay)

    menu_root = Control.new()
    add_child(menu_root)


## Called every frame by Game.
func refresh(score: int, acorns: int, game_over: bool, show_menu: bool, menu_state: String, selection: int) -> void:
    score_label.text = "Points: %d" % score
    acorn_label.text = "Acorns: %d" % acorns
    banner.visible = game_over and not show_menu
    overlay.visible = show_menu
    menu_root.visible = show_menu
    if show_menu:
        var sig := "%s|%d|%d" % [menu_state, selection, score]
        if sig != _menu_signature:
            _menu_signature = sig
            _rebuild_menu(menu_state, selection, score)
    else:
        _menu_signature = ""


func _rebuild_menu(menu_state: String, selection: int, score: int) -> void:
    for child in menu_root.get_children():
        child.queue_free()
    if menu_state == "main":
        menu_root.add_child(_centered("GAME OVER", 64, Color.RED, 150))
        menu_root.add_child(_centered("Final Score: %d" % score, 30, Color.WHITE, 220))
        for i in MENU_ITEMS.size():
            var color := Color.YELLOW if i == selection else Color.WHITE
            menu_root.add_child(_centered(MENU_ITEMS[i], 44, color, 300 + i * 60))
            if i == selection:
                menu_root.add_child(_centered(">", 44, Color.YELLOW, 300 + i * 60, Cfg.SCREEN_W / 2 - 180))
        menu_root.add_child(_centered("Use UP/DOWN to navigate, ENTER/SPACE to select", 24, Color(0.78, 0.78, 0.78), Cfg.SCREEN_H - 50))
    else:
        menu_root.add_child(_centered("Controls", 64, Color.WHITE, 100))
        var cy := 200
        for line in CONTROLS:
            if line != "":
                menu_root.add_child(_centered(line, 26, Color.WHITE, cy))
            cy += 40
        menu_root.add_child(_centered("Press ESC, ENTER, or SPACE to return", 24, Color(0.78, 0.78, 0.78), Cfg.SCREEN_H - 50))


func _label(text: String, size: int, color: Color, px: float, py: float, align: HorizontalAlignment, width: float) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.position = Vector2(px, py)
    l.size = Vector2(width, size * 1.4)
    return l


## Label centred on (cx, cy); cx defaults to the screen middle.
func _centered(text: String, size: int, color: Color, cy: float, cx: float = Cfg.SCREEN_W / 2.0) -> Label:
    var width := 700.0
    var l := _label(text, size, color, cx - width / 2.0, cy - size * 0.7, HORIZONTAL_ALIGNMENT_CENTER, width)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l
