class_name Shop
extends RefCounted
## The between-runs shop: one row per weapon plus the starting-acorns upgrade.
## Pure functions over a Profile so the logic is testable without any UI.

const AMMO_ROW := "ammo_upgrade"


## Rows in display order: {id, name, status, detail}.
static func rows(p: Profile) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for id in Weapons.ORDER:
        var d: Dictionary = Weapons.DEFS[id]
        var status: String
        if p.equipped == id:
            status = "EQUIPPED"
        elif p.owns(id):
            status = "OWNED"
        else:
            status = "%d coins" % d["price"]
        out.append({
            "id": id, "name": d["name"], "status": status,
            "detail": "%s  Costs %d acorn%s per throw." % [d["desc"], d["ammo"], "" if d["ammo"] == 1 else "s"],
        })
    var price := p.ammo_upgrade_price()
    out.append({
        "id": AMMO_ROW, "name": "Bigger Pouch (+1 start acorn)",
        "status": "MAX" if price < 0 else "%d coins" % price,
        "detail": "Start every run with %d acorns (level %d/%d)." % [p.start_ammo(), p.ammo_level, Weapons.AMMO_UPGRADE_PRICES.size()],
    })
    return out


## Buy / equip the row `id`. Returns the message to show the player.
static func activate(p: Profile, id: String) -> String:
    if id == AMMO_ROW:
        if p.ammo_upgrade_price() < 0:
            return "Pouch is already at maximum."
        return "Pouch upgraded!" if p.buy_ammo_upgrade() else "Not enough coins."
    var name: String = Weapons.DEFS[id]["name"]
    if p.owns(id):
        p.equip(id)
        return "%s equipped." % name
    return "Bought %s!" % name if p.buy_weapon(id) else "Not enough coins."
