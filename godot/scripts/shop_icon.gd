class_name ShopIcon
extends Control
## Small icons drawn in code for the shop rows: kind is "heart", "helmet", "matrix", "acorn",
## "spread", "homing", "pinecone" or "boomerang" (the first aid kit is HealthIcon, the chestnut ChestnutIcon).

var kind := "heart"


func _init(icon_kind := "heart", diameter := 22.0) -> void:
    kind = icon_kind
    custom_minimum_size = Vector2(diameter, diameter)
    size = Vector2(diameter, diameter)
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    match kind:
        "heart":
            _draw_heart()
        "helmet":
            _draw_helmet()
        "matrix":
            _draw_matrix()
        "acorn":
            _draw_acorn(Vector2(size.x * 0.5, size.y * 0.5), 1.0, Color8(176, 118, 56), Color8(112, 74, 36))
        "spread":  # three acorns in a fan
            for k: int in [0, 2, 1]:  # (the middle one last: in front)
                var ang := (k - 1) * 0.7
                draw_set_transform(Vector2(size.x * (0.5 + 0.3 * (k - 1)), size.y * (0.52 + 0.06 * absf(k - 1.0))), ang)
                _draw_acorn(Vector2.ZERO, 0.66, Color8(176, 118, 56), Color8(112, 74, 36))
            draw_set_transform(Vector2.ZERO)
        "homing":  # a blue acorn with a curling trail
            _draw_acorn(Vector2(size.x * 0.6, size.y * 0.56), 0.8, Color8(90, 140, 225), Color8(45, 80, 150))
            draw_arc(Vector2(size.x * 0.4, size.y * 0.78), size.x * 0.32, PI * 0.95, PI * 1.45, 8, Color8(120, 190, 255), maxf(1.2, size.x * 0.07))
        "pinecone":
            _draw_pinecone()
        "boomerang":
            _draw_boomerang()


func _draw_heart() -> void:
    var s := size.x
    var red := Color8(225, 35, 55)
    var edge := Color8(110, 10, 25)
    var pts := PackedVector2Array([Vector2(s * 0.06, s * 0.4), Vector2(s * 0.5, s * 0.94), Vector2(s * 0.94, s * 0.4)])
    draw_circle(Vector2(s * 0.29, s * 0.33), s * 0.25, edge)
    draw_circle(Vector2(s * 0.71, s * 0.33), s * 0.25, edge)
    draw_colored_polygon(PackedVector2Array([Vector2(s * 0.02, s * 0.4), Vector2(s * 0.5, s * 0.99), Vector2(s * 0.98, s * 0.4)]), edge)
    draw_circle(Vector2(s * 0.29, s * 0.33), s * 0.21, red)
    draw_circle(Vector2(s * 0.71, s * 0.33), s * 0.21, red)
    draw_colored_polygon(pts, red)
    draw_circle(Vector2(s * 0.24, s * 0.27), s * 0.07, Color(1, 1, 1, 0.7))  # shine


func _draw_helmet() -> void:
    var s := size.x
    var brass := Color8(200, 158, 70)
    var dark := Color8(95, 65, 25)
    draw_rect(Rect2(s * 0.18, s * 0.74, s * 0.64, s * 0.2), dark)                       # neck ring
    draw_rect(Rect2(s * 0.22, s * 0.77, s * 0.56, s * 0.14), Color8(160, 120, 55))
    draw_circle(Vector2(s * 0.5, s * 0.46), s * 0.42, dark)                              # dome
    draw_circle(Vector2(s * 0.5, s * 0.46), s * 0.38, brass)
    draw_circle(Vector2(s * 0.34, s * 0.34), s * 0.1, Color(1, 1, 1, 0.35))              # shine
    draw_circle(Vector2(s * 0.62, s * 0.46), s * 0.2, dark)                              # front porthole
    draw_circle(Vector2(s * 0.62, s * 0.46), s * 0.16, Color8(140, 215, 235))
    draw_arc(Vector2(s * 0.62, s * 0.46), s * 0.16, PI * 1.1, PI * 1.5, 6, Color(1, 1, 1, 0.8), maxf(1.0, s * 0.05))
    draw_circle(Vector2(s * 0.2, s * 0.5), s * 0.09, dark)                               # side porthole
    draw_circle(Vector2(s * 0.2, s * 0.5), s * 0.06, Color8(70, 70, 70))
    for a in [-1.0, -0.4, 0.2]:                                                          # rivets round the front window
        draw_circle(Vector2(s * 0.62, s * 0.46) + Vector2(cos(a * PI), sin(a * PI)) * s * 0.24, s * 0.03, dark)


func _draw_matrix() -> void:
    var s := size.x
    draw_rect(Rect2(0, 0, s, s), Color8(4, 14, 6))
    draw_rect(Rect2(0.5, 0.5, s - 1.0, s - 1.0), Color8(0, 120, 40), false, 1.0)
    # three columns of falling "code": bright head glyph, fading tail
    for col in 3:
        var x := s * (0.2 + 0.3 * col)
        var head := 4 - col  # rows shown; the columns are not level
        for row in head:
            var y := s * (0.1 + 0.2 * row + 0.06 * col)
            var fade := 0.25 + 0.75 * float(row + 1) / head
            var tone := Color(0.1, 1.0, 0.35, fade) if row < head - 1 else Color(0.8, 1.0, 0.85)
            var pat := (col * 3 + row) % 4
            var u := s * 0.07
            match pat:
                0:
                    draw_line(Vector2(x, y), Vector2(x, y + u * 2.4), tone, 1.2)
                    draw_line(Vector2(x - u, y + u * 0.4), Vector2(x + u, y + u * 0.4), tone, 1.2)
                1:
                    draw_line(Vector2(x - u, y), Vector2(x + u, y), tone, 1.2)
                    draw_line(Vector2(x + u, y), Vector2(x - u, y + u * 2.4), tone, 1.2)
                    draw_line(Vector2(x - u, y + u * 2.4), Vector2(x + u, y + u * 2.4), tone, 1.2)
                2:
                    draw_rect(Rect2(x - u, y, u * 2.0, u * 2.4), tone, false, 1.2)
                _:
                    draw_line(Vector2(x - u, y), Vector2(x - u, y + u * 2.4), tone, 1.2)
                    draw_line(Vector2(x - u, y + u * 1.2), Vector2(x + u, y + u * 1.2), tone, 1.2)
                    draw_line(Vector2(x + u, y), Vector2(x + u, y + u * 2.4), tone, 1.2)


## An acorn centred on `c` (the icon's middle, or the origin of a rotated transform); `k` scales it.
func _draw_acorn(c: Vector2, k: float, nut: Color, cap: Color) -> void:
    var s := size.x * k
    var dark := nut.darkened(0.6)
    Shot.fill_ellipse(self, c + Vector2(0.0, s * 0.14), s * 0.34, s * 0.36, dark)               # nut
    Shot.fill_ellipse(self, c + Vector2(0.0, s * 0.14), s * 0.3, s * 0.32, nut)
    Shot.fill_ellipse(self, c + Vector2(-s * 0.08, s * 0.1), s * 0.08, s * 0.14, nut.lightened(0.3))  # shine
    Shot.fill_ellipse(self, c + Vector2(0.0, -s * 0.14), s * 0.42, s * 0.25, dark)              # cap
    Shot.fill_ellipse(self, c + Vector2(0.0, -s * 0.14), s * 0.38, s * 0.21, cap)
    draw_rect(Rect2(c.x - s * 0.04, c.y - s * 0.44, s * 0.08, s * 0.16), dark)                  # stem


func _draw_pinecone() -> void:
    var s := size.x
    var dark := Color8(70, 42, 18)
    var body := Vector2(s * 0.5, s * 0.56)
    Shot.fill_ellipse(self, body, s * 0.3, s * 0.42, dark)
    Shot.fill_ellipse(self, body, s * 0.26, s * 0.38, Color8(160, 112, 58))
    for row in 4:  # overlapping scales: little arcs, offset row by row
        var y := s * (0.3 + 0.17 * row)
        var half := 0.2 - 0.02 * absf(row - 1.5)
        for col in 3:
            var x := s * (0.5 - half + (half * 2.0) * col / 2.0 + (0.07 if row % 2 == 1 else 0.0) - 0.035)
            draw_arc(Vector2(x, y), s * 0.09, 0.0, PI, 6, dark, maxf(1.0, s * 0.06))
    draw_rect(Rect2(s * 0.46, s * 0.04, s * 0.08, s * 0.14), dark)  # stem


func _draw_boomerang() -> void:
    var s := size.x
    var pts := [Vector2(s * 0.1, s * 0.2), Vector2(s * 0.42, s * 0.8), Vector2(s * 0.92, s * 0.52)]
    for pass_i in 2:  # dark outline first, then the wood on top
        var w := s * (0.34 if pass_i == 0 else 0.22)
        var col := Color8(80, 50, 18) if pass_i == 0 else Color8(222, 172, 78)
        draw_line(pts[0], pts[1], col, w)
        draw_line(pts[1], pts[2], col, w)
        for p: Vector2 in pts:  # rounded ends and elbow
            draw_circle(p, w / 2.0, col)
    draw_line(Vector2(s * 0.14, s * 0.26), Vector2(s * 0.4, s * 0.72), Color(1, 1, 1, 0.4), maxf(1.0, s * 0.05))
