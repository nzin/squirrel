class_name Shop
extends RefCounted
## The between-runs shop: one row per weapon, the starting-acorns upgrade and a
## final "start next run" row. Pure functions over a Loadout (testable without UI).

const HEALTH_ROW := "more_health"
const FIST_ROW := "matrix_fist"
const LIFE_ROW := "extra_life"
const ARMOR_ROW := "diver_armor"
const NEXT_RUN_ROW := "next_run"


## Rows in display order: {id, name, status, detail, enabled}. Text is already translated.
## "enabled" is false for what the player cannot pay (or is maxed out): the UI grays it
## out and the cursor skips it. Owned weapons are enabled (equipping is free).
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
                "detail": "%s  %s" % [Lang.t(d["desc"]), Lang.t("Sold in packs of %d; press D to throw one (no acorn needed).", [d["stock"]])],
                "enabled": p.coins >= d["price"],
            })
            continue
        if id == "acorn":  # the plain acorn is always owned: the row sells refills
            out.append({
                "id": id, "name": "%s  x%d  (%s %d)" % [Lang.t(d["name"]), Weapons.ACORN_PACK, Lang.t("in bag"), p.acorns_for_next_run()],
                "status": Lang.t("%d coins", [d["price"]]),
                "detail": "%s  %s" % [Lang.t(d["desc"]), Lang.t("Buy %d acorns for your next run.", [Weapons.ACORN_PACK])],
                "enabled": p.coins >= d["price"],
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
            "enabled": p.owns(id) or p.coins >= d["price"],
        })
    var fist_name := Lang.t("Matrix Fist")
    out.append({
        "id": FIST_ROW,
        "name": "%s  x%d" % [fist_name, Weapons.FIST_PACK] if p.fists == 0 else "%s  x%d  (%s %d)" % [fist_name, Weapons.FIST_PACK, Lang.t("owned"), p.fists],
        "status": Lang.t("%d coins", [Weapons.FIST_PRICE]),
        "detail": Lang.t("Pack of 3 uses (key F): slow-motion dash across the screen, punching everything for 3 damage."),
        "enabled": p.coins >= Weapons.FIST_PRICE,
    })
    out.append({
        "id": ARMOR_ROW, "name": Lang.t("Diver Armor"),
        "status": Lang.t("READY") if p.armor_ready else Lang.t("%d coins", [Weapons.ARMOR_PRICE]),
        "detail": Lang.t("Next run only: 30 health points (1 per hit), but you cannot jump. You throw harpoons (1 acorn each)."),
        "enabled": not p.armor_ready and p.coins >= Weapons.ARMOR_PRICE,
    })
    out.append({
        "id": LIFE_ROW, "name": Lang.t("Extra Life"),
        "status": Lang.t("MAX") if p.lives >= Weapons.MAX_LIVES else Lang.t("%d coins", [Weapons.LIFE_PRICE]),
        "detail": Lang.t("Lives: %d/%d. Also won from bosses and 1UP hearts.", [p.lives, Weapons.MAX_LIVES]),
        "enabled": p.lives < Weapons.MAX_LIVES and p.coins >= Weapons.LIFE_PRICE,
    })
    var price := p.health_upgrade_price()
    out.append({
        "id": HEALTH_ROW, "name": Lang.t("More health"),
        "status": Lang.t("MAX") if price < 0 else Lang.t("%d coins", [price]),
        "detail": Lang.t("Each life starts with %d health points (level %d/%d). A hit costs 1 point.", [p.max_health(), p.health_level, Weapons.HEALTH_UPGRADE_PRICES.size()]),
        "enabled": price >= 0 and p.coins >= price,
    })
    out.append({
        "id": NEXT_RUN_ROW,
        "name": Lang.t("Start run %d (BOSS)", [next_run]) if next_is_boss else Lang.t("Start run %d", [next_run]),
        "status": ">>", "detail": "", "enabled": true,
    })
    return out


## Buy / equip the row `id`. Returns the message to show the player
## (NEXT_RUN_ROW is handled by the caller).
static func activate(p: Loadout, id: String) -> String:
    if id == LIFE_ROW:
        if p.lives >= Weapons.MAX_LIVES:
            return Lang.t("You already have the maximum lives.")
        return Lang.t("Extra life!") if p.buy_life() else Lang.t("Not enough coins.")
    if id == ARMOR_ROW:
        if p.armor_ready:
            return Lang.t("The Diver Armor is already waiting for your next run.")
        return Lang.t("Diver Armor ready for your next run!") if p.buy_armor() else Lang.t("Not enough coins.")
    if id == FIST_ROW:
        return Lang.t("Bought %s!", [Lang.t("Matrix Fist")]) if p.buy_fist() else Lang.t("Not enough coins.")
    if id == HEALTH_ROW:
        if p.health_upgrade_price() < 0:
            return Lang.t("Health is already at maximum.")
        return Lang.t("Health up!") if p.buy_health() else Lang.t("Not enough coins.")
    var wname: String = Lang.t(Weapons.DEFS[id]["name"])
    if id == "acorn":  # a refill of acorns, not a weapon to own
        return Lang.t("Bought %s!", ["%s x%d" % [wname, Weapons.ACORN_PACK]]) if p.buy_acorns() else Lang.t("Not enough coins.")
    if Weapons.DEFS[id].has("stock"):  # buy another pack
        var bought := "%s x%d" % [wname, Weapons.DEFS[id]["stock"]]
        return Lang.t("Bought %s!", [bought]) if p.buy_weapon(id) else Lang.t("Not enough coins.")
    if p.owns(id):
        p.equip(id)
        return Lang.t("%s equipped.", [wname])
    return Lang.t("Bought %s!", [wname]) if p.buy_weapon(id) else Lang.t("Not enough coins.")
