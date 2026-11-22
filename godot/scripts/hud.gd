class_name Hud
extends CanvasLayer
## Score / acorn counters, the "GAME OVER" banner and the restart/controls menu.

## "Quit" is meaningless in a browser tab, so the web build leaves it out.
static func menu_items() -> Array[String]:
    var items: Array[String] = ["Restart", "Shop", "Show Controls"]
    if not OS.has_feature("web"):
        items.append("Quit")
    return items

const CONTROLS := [
    "SPACE - Jump",
    "SHIFT - Throw weapon",
    "Q - Switch weapon",
    "",
    "Boxes give acorns (ammo) and coins.",
    "Defeated enemies drop coins.",
    "Spend coins in the Shop after a run.",
    "You can stand on trees and enemies!",
]

var score_label: Label
var acorn_label: Label
var coin_label: Label
var weapon_label: Label
var banner: Label
var overlay: ColorRect
var menu_root: Control
var _menu_signature := ""


func _ready() -> void:
    score_label = _label("", 30, Color.BLACK, 10, 10, HORIZONTAL_ALIGNMENT_LEFT, 300)
    acorn_label = _label("", 30, Color.BLACK, Cfg.SCREEN_W - 310, 10, HORIZONTAL_ALIGNMENT_RIGHT, 300)
    coin_label = _label("", 26, Color(0.55, 0.38, 0.0), Cfg.SCREEN_W - 310, 46, HORIZONTAL_ALIGNMENT_RIGHT, 300)
    weapon_label = _label("", 22, Color.BLACK, 10, 48, HORIZONTAL_ALIGNMENT_LEFT, 400)
    add_child(score_label)
    add_child(acorn_label)
    add_child(coin_label)
    add_child(weapon_label)

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


## Called every frame by Game with a snapshot of what to show (see Game._hud_state).
func refresh(st: Dictionary) -> void:
    var show_menu: bool = st["show_menu"]
    score_label.text = "Points: %d" % st["score"]
    acorn_label.text = "Acorns: %d" % st["acorns"]
    coin_label.text = "Coins: %d" % st["coins"]
    weapon_label.text = "%s (%d ammo)  [Q]" % [st["weapon"], st["weapon_ammo"]]
    banner.visible = st["game_over"] and not show_menu
    overlay.visible = show_menu
    menu_root.visible = show_menu
    if show_menu:
        var sig := str([st["menu_state"], st["selection"], st["score"], st["coins"], st["best"],
            st["shop_rows"], st["shop_selection"], st["shop_message"]])
        if sig != _menu_signature:
            _menu_signature = sig
            _rebuild_menu(st)
    else:
        _menu_signature = ""


func _rebuild_menu(st: Dictionary) -> void:
    for child in menu_root.get_children():
        child.queue_free()
    var grey := Color(0.78, 0.78, 0.78)
    match st["menu_state"]:
        "main":
            menu_root.add_child(_centered("GAME OVER", 64, Color.RED, 130))
            menu_root.add_child(_centered("Final Score: %d   (Best: %d)" % [st["score"], st["best"]], 28, Color.WHITE, 195))
            menu_root.add_child(_centered("Coins: %d" % st["coins"], 28, Color(1.0, 0.85, 0.2), 232))
            var items := menu_items()
            for i in items.size():
                var color := Color.YELLOW if i == st["selection"] else Color.WHITE
                menu_root.add_child(_centered(items[i], 44, color, 305 + i * 58))
                if i == st["selection"]:
                    menu_root.add_child(_centered(">", 44, Color.YELLOW, 305 + i * 58, Cfg.SCREEN_W / 2 - 180))
            menu_root.add_child(_centered("Use UP/DOWN to navigate, ENTER/SPACE to select", 24, grey, Cfg.SCREEN_H - 40))
        "shop":
            menu_root.add_child(_centered("SHOP", 54, Color.WHITE, 55))
            menu_root.add_child(_centered("Coins: %d" % st["coins"], 30, Color(1.0, 0.85, 0.2), 105))
            var rows: Array = st["shop_rows"]
            for i in rows.size():
                var row: Dictionary = rows[i]
                var sel: bool = i == st["shop_selection"]
                var y := 150.0 + i * 40.0
                var col := Color.YELLOW if sel else Color.WHITE
                if row["status"] == "EQUIPPED":
                    col = Color(0.5, 1.0, 0.5)
                if sel:
                    menu_root.add_child(_label(">", 30, Color.YELLOW, 60, y, HORIZONTAL_ALIGNMENT_LEFT, 40))
                menu_root.add_child(_label(row["name"], 28, col, 95, y, HORIZONTAL_ALIGNMENT_LEFT, 440))
                menu_root.add_child(_label(row["status"], 28, col, 500, y, HORIZONTAL_ALIGNMENT_RIGHT, 220))
            menu_root.add_child(_centered(rows[st["shop_selection"]]["detail"], 20, grey, 500))
            if st["shop_message"] != "":
                menu_root.add_child(_centered(st["shop_message"], 28, Color(1.0, 0.85, 0.2), 538))
            menu_root.add_child(_centered("UP/DOWN select - ENTER buy / equip - ESC back", 22, grey, Cfg.SCREEN_H - 24))
        _:
            menu_root.add_child(_centered("Controls", 64, Color.WHITE, 90))
            var cy := 180
            for line in CONTROLS:
                if line != "":
                    menu_root.add_child(_centered(line, 26, Color.WHITE, cy))
                cy += 40
            menu_root.add_child(_centered("Press ESC, ENTER, or SPACE to return", 24, grey, Cfg.SCREEN_H - 50))


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
