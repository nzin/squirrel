class_name Hud
extends CanvasLayer
## Everything drawn over the world: counters, run timer / progress line, boss
## health bar, banners, the pause / game-over / shop / controls menus and the
## full-screen fade used between runs. Game pushes a state dictionary every
## frame (see Game._hud_state); all text goes through Lang.t().

const CONTROLS := [
    "SPACE - Jump",
    "SHIFT - Throw weapon",
    "Q - Switch weapon",
    "F - Matrix Fist (slow-motion punch)",
    "ESC - Pause menu",
    "",
    "Survive 60 s per run. A boss waits every 3rd run!",
    "Boxes give acorns (ammo) and coins.",
    "Defeated enemies drop coins.",
    "Spend coins in the Shop between runs.",
    "You can stand on trees and enemies!",
]
const GOLD := Color(1.0, 0.85, 0.2)
const GREY := Color(0.78, 0.78, 0.78)
const BAR_H := 8.0
const BOSS_BAR := Vector2(300.0, 14.0)

var score_label: Label
var acorn_label: Label
var coin_label: Label
var coin_icon: CoinIcon
var weapon_label: Label
var fist_icon: FistIcon
var fist_label: Label
var matrix_tint: ColorRect
var matrix_dim: ColorRect
var life_icons: Array[TextureRect] = []
var bar_top: ColorRect
var bar_bottom: ColorRect
var run_label: Label
var banner: Label
var progress_bg: ColorRect
var progress_fill: ColorRect
var progress_boss_mark: ColorRect
var boss_bg: ColorRect
var boss_fill: ColorRect
var overlay: ColorRect
var menu_root: Control
var fade_rect: ColorRect
var _menu_signature := ""


const LETTERBOX := 44.0


func _ready() -> void:
    # Matrix slow-motion look: blue tint + cinematic bars, under the HUD texts
    matrix_tint = _rect(Color(0.1, 0.35, 0.8, 0.0), 0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)
    matrix_dim = _rect(Color(0, 0, 0, 0.0), 0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)
    bar_top = _rect(Color.BLACK, 0, 0, Cfg.SCREEN_W, 0)
    bar_bottom = _rect(Color.BLACK, 0, Cfg.SCREEN_H, Cfg.SCREEN_W, 0)
    for n: Node in [matrix_dim, matrix_tint, bar_top, bar_bottom]:
        add_child(n)

    score_label = _label("", 30, Color.BLACK, 10, 10, HORIZONTAL_ALIGNMENT_LEFT, 300)
    acorn_label = _label("", 30, Color.BLACK, Cfg.SCREEN_W - 310, 10, HORIZONTAL_ALIGNMENT_RIGHT, 300)
    coin_label = _label("", 26, Color(0.55, 0.38, 0.0), Cfg.SCREEN_W - 310, 46, HORIZONTAL_ALIGNMENT_RIGHT, 300)
    coin_icon = CoinIcon.new(24.0)
    weapon_label = _label("", 22, Color.BLACK, 10, 74, HORIZONTAL_ALIGNMENT_LEFT, 400)
    run_label = _label("", 24, Color.BLACK, Cfg.SCREEN_W / 2.0 - 120, 8, HORIZONTAL_ALIGNMENT_CENTER, 240)
    fist_icon = FistIcon.new(26.0)
    fist_icon.position = Vector2(10, 102)
    fist_label = _label("", 24, Color.BLACK, 42, 102, HORIZONTAL_ALIGNMENT_LEFT, 200)
    for n: Node in [score_label, acorn_label, coin_label, coin_icon, weapon_label, run_label, fist_icon, fist_label]:
        add_child(n)
    # one small squirrel per life
    for i in Weapons.MAX_LIVES:
        var icon := TextureRect.new()
        icon.texture = Cfg.tex("squirrel.png")
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_SCALE
        icon.size = Vector2(26, 26)
        icon.position = Vector2(10 + i * 30, 44)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(icon)
        life_icons.append(icon)

    boss_bg = _rect(Color(0, 0, 0, 0.55), Cfg.SCREEN_W / 2.0 - BOSS_BAR.x / 2.0, 42, BOSS_BAR.x, BOSS_BAR.y)
    boss_fill = _rect(Color(0.85, 0.12, 0.12), Cfg.SCREEN_W / 2.0 - BOSS_BAR.x / 2.0, 42, BOSS_BAR.x, BOSS_BAR.y)
    progress_bg = _rect(Color(0, 0, 0, 0.45), 0, Cfg.SCREEN_H - BAR_H, Cfg.SCREEN_W, BAR_H)
    progress_fill = _rect(GOLD, 0, Cfg.SCREEN_H - BAR_H, 0, BAR_H)
    progress_boss_mark = _rect(Color(0.9, 0.1, 0.1), Cfg.SCREEN_W - 6, Cfg.SCREEN_H - BAR_H, 6, BAR_H)
    for r: Node in [boss_bg, boss_fill, progress_bg, progress_fill, progress_boss_mark]:
        add_child(r)

    banner = _centered("", 64, Color.RED, Cfg.SCREEN_H / 2.0)
    banner.visible = false
    add_child(banner)

    overlay = _rect(Color(0, 0, 0, 200.0 / 255.0), 0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)
    overlay.visible = false
    add_child(overlay)

    menu_root = Control.new()
    add_child(menu_root)

    fade_rect = _rect(Color(0, 0, 0, 0), 0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)  # topmost
    add_child(fade_rect)


## Called every frame by Game with a snapshot of what to show.
func refresh(st: Dictionary) -> void:
    var in_run: bool = st["in_run"]
    var show_menu: bool = st["show_menu"]

    score_label.text = Lang.t("Points: %d", [st["score"]])
    acorn_label.text = Lang.t("Acorns: %d", [st["acorns"]])
    coin_label.text = str(st["coins"])
    var font := coin_label.get_theme_font("font")
    var text_w := font.get_string_size(coin_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
    coin_icon.position = Vector2(Cfg.SCREEN_W - 10.0 - text_w - 30.0, 47.0)
    weapon_label.text = Lang.t("%s (%d ammo)  [Q]", [Lang.t(st["weapon"]), st["weapon_ammo"]])

    var fists: int = st["fists"]
    fist_icon.visible = in_run and fists > 0
    fist_label.visible = fist_icon.visible
    fist_label.text = "x%d  [F]" % fists
    var m: float = st["matrix"]
    matrix_tint.color.a = 0.12 * m
    matrix_dim.color.a = 0.38 * m  # the light dims as time slows and comes back with it
    var lives: int = st["lives"]
    for i in life_icons.size():
        life_icons[i].visible = in_run and i < lives
    bar_top.size.y = LETTERBOX * m
    bar_bottom.size.y = LETTERBOX * m
    bar_bottom.position.y = Cfg.SCREEN_H - LETTERBOX * m
    # black HUD text would vanish on the black cinematic bars
    var ink := Color.WHITE if m > 0.35 else Color.BLACK
    for l: Label in [score_label, acorn_label, weapon_label, run_label, fist_label]:
        l.add_theme_color_override("font_color", ink)

    run_label.visible = in_run
    progress_bg.visible = in_run
    progress_fill.visible = in_run
    progress_boss_mark.visible = in_run and st["is_boss_run"]
    if in_run:
        var left := ceili(st["time_left"])
        run_label.text = "%s   %d:%02d" % [Lang.t("RUN %d", [st["run"]]), left / 60, left % 60]
        if st["boss_max"] > 0:
            run_label.text = "%s   %s" % [Lang.t("RUN %d", [st["run"]]), Lang.t("BOSS")]
        progress_fill.size.x = Cfg.SCREEN_W * clampf(st["progress"], 0.0, 1.0)
    var boss_on: bool = in_run and st["boss_max"] > 0
    boss_bg.visible = boss_on
    boss_fill.visible = boss_on
    if boss_on:
        boss_fill.size.x = BOSS_BAR.x * clampf(float(st["boss_hp"]) / st["boss_max"], 0.0, 1.0)

    banner.visible = st["banner_text"] != "" and not show_menu
    if banner.visible:
        banner.text = st["banner_text"]
        banner.add_theme_color_override("font_color", st["banner_color"])
    overlay.visible = show_menu
    menu_root.visible = show_menu
    fade_rect.color.a = st["fade"]

    if show_menu:
        var sig := str([st["menu_state"], st["selection"], st["menu_items"], st["score"], st["best"], st["run"],
            st["coins"], st["shop_rows"], st["shop_selection"], st["shop_message"], Lang.current])
        if sig != _menu_signature:
            _menu_signature = sig
            _rebuild_menu(st)
    else:
        _menu_signature = ""


func _rebuild_menu(st: Dictionary) -> void:
    for child in menu_root.get_children():
        child.queue_free()
    match st["menu_state"]:
        "main":
            menu_root.add_child(_centered(Lang.t("GAME OVER"), 64, Color.RED, 120))
            menu_root.add_child(_centered(Lang.t("Reached run %d", [st["run"]]), 28, GOLD, 185))
            menu_root.add_child(_centered(Lang.t("Final Score: %d   (Best: %d)", [st["score"], st["best"]]), 28, Color.WHITE, 222))
            _menu_items(st, 290.0)
        "pause":
            menu_root.add_child(_centered(Lang.t("PAUSED"), 58, Color.WHITE, 100))
            _menu_items(st, 190.0)
        "shop":
            _shop_screen(st)
        _:
            menu_root.add_child(_centered(Lang.t("Controls"), 64, Color.WHITE, 80))
            var cy := 165
            for line: String in CONTROLS:
                if line != "":
                    menu_root.add_child(_centered(Lang.t(line), 26, Color.WHITE, cy))
                cy += 38
            menu_root.add_child(_centered(Lang.t("Press ESC, ENTER, or SPACE to return"), 24, GREY, Cfg.SCREEN_H - 50))


func _menu_items(st: Dictionary, start_y: float) -> void:
    var items: Array = st["menu_items"]
    for i in items.size():
        var color := Color.YELLOW if i == st["selection"] else Color.WHITE
        var y := start_y + i * 58.0
        menu_root.add_child(_centered(items[i], 44, color, y))
        if i == st["selection"]:
            menu_root.add_child(_centered(">", 44, Color.YELLOW, y, Cfg.SCREEN_W / 2.0 - 250.0))
    menu_root.add_child(_centered(Lang.t("Use UP/DOWN to navigate, ENTER/SPACE to select"), 22, GREY, Cfg.SCREEN_H - 62))
    menu_root.add_child(_centered(Lang.t("LEFT/RIGHT changes the language"), 20, GREY, Cfg.SCREEN_H - 34))


func _shop_screen(st: Dictionary) -> void:
    menu_root.add_child(_centered(Lang.t("SHOP"), 50, Color.WHITE, 45))
    _coin_row(st["coins"], 30, 92.0)
    var rows: Array = st["shop_rows"]
    for i in rows.size():
        var row: Dictionary = rows[i]
        var sel: bool = i == st["shop_selection"]
        var y := 118.0 + i * 31.0
        var col := Color.YELLOW if sel else Color.WHITE
        if row["id"] == Shop.NEXT_RUN_ROW:
            y += 10.0
            col = Color(0.5, 1.0, 0.5) if not sel else Color.YELLOW
        elif row["status"] == Lang.t("EQUIPPED"):
            col = Color(0.5, 1.0, 0.5)
        if sel:
            menu_root.add_child(_label(">", 28, Color.YELLOW, 60, y, HORIZONTAL_ALIGNMENT_LEFT, 40))
        menu_root.add_child(_label(row["name"], 24, col, 95, y, HORIZONTAL_ALIGNMENT_LEFT, 480))
        menu_root.add_child(_label(row["status"], 24, col, 500, y, HORIZONTAL_ALIGNMENT_RIGHT, 220))
    menu_root.add_child(_centered(rows[st["shop_selection"]]["detail"], 19, GREY, 500))
    if st["shop_message"] != "":
        menu_root.add_child(_centered(st["shop_message"], 26, GOLD, 538))
    menu_root.add_child(_centered(Lang.t("UP/DOWN select - ENTER buy / equip"), 20, GREY, Cfg.SCREEN_H - 22))


## "<coin icon> 47" centred on the screen.
func _coin_row(amount: int, size: int, cy: float) -> void:
    var txt := str(amount)
    var font := ThemeDB.fallback_font
    var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    var icon_d := size * 0.95
    var total := icon_d + 10.0 + tw
    var left := Cfg.SCREEN_W / 2.0 - total / 2.0
    var icon := CoinIcon.new(icon_d)
    icon.position = Vector2(left, cy - icon_d / 2.0)
    menu_root.add_child(icon)
    menu_root.add_child(_label(txt, size, GOLD, left + icon_d + 10.0, cy - size * 0.7, HORIZONTAL_ALIGNMENT_LEFT, tw + 20.0))


func _rect(color: Color, px: float, py: float, w: float, h: float) -> ColorRect:
    var r := ColorRect.new()
    r.color = color
    r.position = Vector2(px, py)
    r.size = Vector2(w, h)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r


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
    var width := 760.0
    var l := _label(text, size, color, cx - width / 2.0, cy - size * 0.7, HORIZONTAL_ALIGNMENT_CENTER, width)
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return l
