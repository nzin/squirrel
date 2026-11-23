class_name Shop
extends RefCounted
## The between-runs shop: one row per weapon, the starting-acorns upgrade and a
## final "start next run" row. Pure functions over a Loadout (testable without UI).

const AMMO_ROW := "ammo_upgrade"
const FIST_ROW := "matrix_fist"
const LIFE_ROW := "extra_life"
const NEXT_RUN_ROW := "next_run"


## Rows in display order: {id, name, status, detail}. Text is already translated.
static func rows(p: Loadout, next_run: int, next_is_boss: bool) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for id in Weapons.ORDER:
        var d: Dictionary = Weapons.DEFS[id]
        if d.has("stock"):  # a pack of consumables: always buyable, shows how many are left
            var left := p.stock_left(id)
            var pack_name := "%s  x%d" % [Lang.t(d["name"]), d["stock"]]
            out.append({
                "id": id, "name": pack_name if left <= 0 else "%s %s" % [pack_name, Lang.t("(%d left)", [left])],
                "status": Lang.t("%d coins", [d["price"]]),
                "detail": "%s  %s" % [Lang.t(d["desc"]), Lang.t("Sold in packs of %d; uses no acorns.", [d["stock"]])],
            })
            continue
        var status: String
        if p.equipped == id:
            status = Lang.t("EQUIPPED")
        elif p.owns(id):
            status = Lang.t("OWNED")
        else:
            status = Lang.t("%d coins", [d["price"]])
        var cost := Lang.t("Costs 1 acorn per throw.") if d["ammo"] == 1 else Lang.t("Costs %d acorns per throw.", [d["ammo"]])
        out.append({
            "id": id, "name": Lang.t(d["name"]), "status": status,
            "detail": "%s  %s" % [Lang.t(d["desc"]), cost],
        })
    var fist_name := Lang.t("Matrix Fist")
    out.append({
        "id": FIST_ROW,
        "name": "%s  x%d" % [fist_name, Weapons.FIST_PACK] if p.fists == 0 else "%s  x%d  (%s %d)" % [fist_name, Weapons.FIST_PACK, Lang.t("owned"), p.fists],
        "status": Lang.t("%d coins", [Weapons.FIST_PRICE]),
        "detail": Lang.t("Pack of 3 uses (key F): slow-motion dash across the screen, punching everything for 3 damage."),
    })
    out.append({
        "id": LIFE_ROW, "name": Lang.t("Extra Life"),
        "status": Lang.t("MAX") if p.lives >= Weapons.MAX_LIVES else Lang.t("%d coins", [Weapons.LIFE_PRICE]),
        "detail": Lang.t("Lives: %d/%d. Also won from bosses and 1UP hearts.", [p.lives, Weapons.MAX_LIVES]),
    })
    var price := p.ammo_upgrade_price()
    out.append({
        "id": AMMO_ROW, "name": Lang.t("Bigger Pouch (+1 start acorn)"),
        "status": Lang.t("MAX") if price < 0 else Lang.t("%d coins", [price]),
        "detail": Lang.t("Start every run with %d acorns (level %d/%d).", [p.start_ammo(), p.ammo_level, Weapons.AMMO_UPGRADE_PRICES.size()]),
    })
    out.append({
        "id": NEXT_RUN_ROW,
        "name": Lang.t("Start run %d (BOSS)", [next_run]) if next_is_boss else Lang.t("Start run %d", [next_run]),
        "status": ">>", "detail": "",
    })
    return out


## Buy / equip the row `id`. Returns the message to show the player
## (NEXT_RUN_ROW is handled by the caller).
static func activate(p: Loadout, id: String) -> String:
    if id == LIFE_ROW:
        if p.lives >= Weapons.MAX_LIVES:
            return Lang.t("You already have the maximum lives.")
        return Lang.t("Extra life!") if p.buy_life() else Lang.t("Not enough coins.")
    if id == FIST_ROW:
        return Lang.t("Bought %s!", [Lang.t("Matrix Fist")]) if p.buy_fist() else Lang.t("Not enough coins.")
    if id == AMMO_ROW:
        if p.ammo_upgrade_price() < 0:
            return Lang.t("Pouch is already at maximum.")
        return Lang.t("Pouch upgraded!") if p.buy_ammo_upgrade() else Lang.t("Not enough coins.")
    var wname: String = Lang.t(Weapons.DEFS[id]["name"])
    if Weapons.DEFS[id].has("stock"):  # buy another pack
        var bought := "%s x%d" % [wname, Weapons.DEFS[id]["stock"]]
        return Lang.t("Bought %s!", [bought]) if p.buy_weapon(id) else Lang.t("Not enough coins.")
    if p.owns(id):
        p.equip(id)
        return Lang.t("%s equipped.", [wname])
    return Lang.t("Bought %s!", [wname]) if p.buy_weapon(id) else Lang.t("Not enough coins.")
