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
var shop_dwarf: TextureRect    # the shopkeeper (visible only in the shop)
var shop_mood_shown := "idle"  # what the shopkeeper is doing: idle | talk | happy
var _talk_until := 0.0         # (seconds) the shopkeeper speaks until then
var _custom_keeper: Texture2D  # optional local-only shopkeeper picture, see CUSTOM_SHOPKEEPER
var _keeper_base := Vector2.ZERO
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
## Optional shopkeeper picture (a transparent PNG) that replaces the built-in dwarf.
## It lives in the git-ignored godot/private/ folder, so licensed art that must not
## be redistributed never ends up in the public repository (see CREDITS.md).
const CUSTOM_SHOPKEEPER := "res://private/shopkeeper.png"


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

    if ResourceLoader.exists(CUSTOM_SHOPKEEPER):
        _custom_keeper = load(CUSTOM_SHOPKEEPER)
    shop_dwarf = TextureRect.new()
    shop_dwarf.texture = _custom_keeper if _custom_keeper != null else Cfg.tex("dwarf_idle.png")
    shop_dwarf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shop_dwarf.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    if _custom_keeper != null:  # a full-length standing figure: tall and narrow
        _keeper_base = Vector2(636, 366)
        shop_dwarf.size = Vector2(150, 228)
    else:  # the dwarf behind his counter
        _keeper_base = Vector2(628, 388)
        shop_dwarf.size = Vector2(164, 205)
    shop_dwarf.position = _keeper_base
    shop_dwarf.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_dwarf.visible = false
    add_child(shop_dwarf)

    menu_root = Control.new()
    add_child(menu_root)

    fade_rect = _rect(Color(0, 0, 0, 0), 0, 0, Cfg.SCREEN_W, Cfg.SCREEN_H)  # topmost
    add_child(fade_rect)


## Called every frame by Game with a snapshot of what to show.
func refresh(st: Dictionary) -> void:
    var in_run: bool = st["in_run"]
    var show_menu: bool = st["show_menu"]
    var in_shop: bool = show_menu and st["menu_state"] == "shop"
    # the shop is its own screen: the in-game counters would only clutter it
    for n: CanvasItem in [score_label, acorn_label, coin_label, coin_icon, weapon_label]:
        n.visible = not in_shop

    score_label.text = Lang.t("Points: %d", [st["score"]])
    acorn_label.text = Lang.t("Acorns: %d", [st["acorns"]])
    coin_label.text = str(st["coins"])
    var font := coin_label.get_theme_font("font")
    var text_w := font.get_string_size(coin_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
    coin_icon.position = Vector2(Cfg.SCREEN_W - 10.0 - text_w - 30.0, 47.0)
    weapon_label.text = Lang.t("%s (%d ammo)  [Q]", [Lang.t(st["weapon"]), st["weapon_ammo"]])

    var fists: int = st["fists"]
    fist_icon.visible = in_run and fists > 0 and not in_shop
    fist_label.visible = fist_icon.visible
    fist_label.text = "x%d  [F]" % fists
    var m: float = st["matrix"]
    matrix_tint.color.a = 0.12 * m
    matrix_dim.color.a = 0.38 * m  # the light dims as time slows and comes back with it
    var lives: int = st["lives"]
    for i in life_icons.size():
        life_icons[i].visible = in_run and i < lives and not in_shop
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

    shop_dwarf.visible = in_shop
    if show_menu:
        var sig := str([st["menu_state"], st["selection"], st["menu_items"], st["score"], st["best"], st["run"],
            st["coins"], st["shop_rows"], st["shop_selection"], st["shop_message"], Lang.current])
        if sig != _menu_signature:
            _menu_signature = sig
            if in_shop:
                _talk_until = Time.get_ticks_msec() / 1000.0 + 1.1  # new line of dialogue
            _rebuild_menu(st)
        if in_shop:
            _animate_dwarf(st["shop_mood"])
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


const SHELF_W := 584.0                     # the wares' shelf takes most of the screen...
const SHOP_CX := 28.0 + SHELF_W / 2.0      # ...and is centred here; the dwarf is a small figure on the right


## Picks the dwarf's picture: delighted after a purchase, mouth moving while he
## speaks, otherwise idle.
func _animate_dwarf(mood: String) -> void:
    var now := Time.get_ticks_msec() / 1000.0
    var talking := now < _talk_until
    shop_mood_shown = "happy" if mood == "happy" else ("talk" if talking else "idle")
    if _custom_keeper != null:
        # a single picture: it breathes, bobs while talking and hops for joy
        var bob := sin(now * 2.2) * 1.5
        if mood == "happy":
            bob = -absf(sin(now * 9.0)) * 12.0
        elif talking:
            bob = -absf(sin(now * 14.0)) * 4.0
        shop_dwarf.position = _keeper_base + Vector2(0.0, bob)
        return
    var tex := "dwarf_idle.png"
    if mood == "happy":
        tex = "dwarf_happy.png"
    elif talking and int(now * 7.0) % 2 == 0:
        tex = "dwarf_talk.png"
    shop_dwarf.texture = Cfg.tex(tex)


func _shop_screen(st: Dictionary) -> void:
    # a wooden shelf board for the wares
    menu_root.add_child(_rect(Color(0.22, 0.14, 0.08, 0.92), 28, 112, SHELF_W, 386))
    menu_root.add_child(_rect(Color(0.62, 0.42, 0.22), 28, 112, SHELF_W, 4))
    menu_root.add_child(_rect(Color(0.62, 0.42, 0.22), 28, 494, SHELF_W, 4))
    menu_root.add_child(_centered(Lang.t("SHOP"), 46, Color.WHITE, 42, SHOP_CX))
    _coin_row(st["coins"], 28, 88.0, SHOP_CX)
    var rows: Array = st["shop_rows"]
    for i in rows.size():
        var row: Dictionary = rows[i]
        var sel: bool = i == st["shop_selection"]
        var y := 124.0 + i * 31.0
        var col := Color.YELLOW if sel else Color.WHITE
        if row["id"] == Shop.NEXT_RUN_ROW:
            y += 10.0
            col = Color(0.5, 1.0, 0.5) if not sel else Color.YELLOW
        elif row["status"] == Lang.t("EQUIPPED"):
            col = Color(0.5, 1.0, 0.5)
        if sel:
            menu_root.add_child(_rect(Color(1, 1, 1, 0.12), 36, y - 1, SHELF_W - 16, 29))
            menu_root.add_child(_label(">", 24, Color.YELLOW, 40, y, HORIZONTAL_ALIGNMENT_LEFT, 24))
        menu_root.add_child(_label(row["name"], 22, col, 66, y, HORIZONTAL_ALIGNMENT_LEFT, 440))
        menu_root.add_child(_label(row["status"], 22, col, 450, y, HORIZONTAL_ALIGNMENT_RIGHT, 140))
    # the shopkeeper talks: what you just did, else a description of the selected ware
    var line: String = st["shop_message"]
    if line == "":
        line = rows[st["shop_selection"]]["detail"]
    if line == "":
        line = Lang.t("Ready for the next run?")
    _speech_bubble(line, Vector2(626, 118), Vector2(168, 222 if _custom_keeper != null else 240))
    menu_root.add_child(_centered(Lang.t("UP/DOWN select - ENTER buy / equip"), 20, GREY, Cfg.SCREEN_H - 22, SHOP_CX))


## A cream speech bubble whose tail points down at the shopkeeper.
func _speech_bubble(text: String, pos: Vector2, size: Vector2) -> void:
    var panel := Panel.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.99, 0.95, 0.82)
    sb.border_color = Color(0.35, 0.22, 0.1)
    sb.set_border_width_all(3)
    sb.set_corner_radius_all(14)
    panel.add_theme_stylebox_override("panel", sb)
    panel.position = pos
    panel.size = size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu_root.add_child(panel)
    var tail := Polygon2D.new()
    var base := pos + Vector2(size.x * 0.5, size.y - 1.0)
    tail.polygon = PackedVector2Array([base + Vector2(-16, 0), base + Vector2(16, 0), base + Vector2(0, 28)])
    tail.color = sb.bg_color
    menu_root.add_child(tail)
    var edge := Line2D.new()
    edge.points = PackedVector2Array([base + Vector2(-16, 0), base + Vector2(0, 28), base + Vector2(16, 0)])
    edge.width = 3.0
    edge.default_color = sb.border_color
    menu_root.add_child(edge)
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 17)
    label.add_theme_color_override("font_color", Color(0.25, 0.14, 0.06))
    label.position = pos + Vector2(12, 8)
    label.size = size - Vector2(24, 16)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    menu_root.add_child(label)


## "<coin icon> 47" centred on `cx`.
func _coin_row(amount: int, size: int, cy: float, cx: float = Cfg.SCREEN_W / 2.0) -> void:
    var txt := str(amount)
    var font := ThemeDB.fallback_font
    var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    var icon_d := size * 0.95
    var total := icon_d + 10.0 + tw
    var left := cx - total / 2.0
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
