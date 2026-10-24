extends HumanNPC
## A trader. Look at them and press E (X on a controller) to buy and sell.
## Anything you sell is added to their stock, so you can buy it back (at the
## higher price). Each trader scene can have its own stock and prices.
## Every morning they restock: each item in starting_stock is topped back up to
## its starting amount (things you sold them on top of that are kept). Things in
## rare_stock (the wagon trader's guns) come back only now and then: each
## morning, each one they're short of has rare_chance of turning up.
## TUNING: open shopkeeper.tscn, select the Shopkeeper node, and use the Inspector.

const Inventory := preload("res://items/inventory.gd")

@export_group("Shop")
## What the trader starts with. Keys must be item ids (the files in items/data/).
@export var starting_stock: Dictionary[String, int] = {
	"pistol_ammo": 60, "shotgun_shells": 10, "rifle_rounds": 5, "health_pack": 3, "crowbar": 1, "canned_food": 4,
	"batteries": 4, "planks": 8, "barricade": 3, "plywood": 4, "scrap_metal": 4,
}
## Dollars you pay per item.
@export var buy_prices: Dictionary[String, int] = {
	"pistol": 250, "crowbar": 60, "pistol_ammo": 4, "shotgun_shells": 7, "rifle_rounds": 12, "health_pack": 45,
	"canned_food": 15, "batteries": 12, "planks": 10, "barricade": 35, "plywood": 12, "scrap_metal": 10,
}
## In stock at the start, and back now and then (see rare_chance), not every morning.
@export var rare_stock: Dictionary[String, int] = {}
## Each morning, the chance (0-1) that each rare item they're out of comes back.
@export_range(0.0, 1.0) var rare_chance := 0.25
## Hour of the morning (0-23) when the day's restock arrives.
@export_range(0, 23) var restock_hour := 6
## Dollars you get per item. Leave an item out and the trader won't buy it.
@export var sell_prices: Dictionary[String, int] = {
	"pistol": 90, "shotgun": 70, "rifle": 110, "crowbar": 20, "pistol_ammo": 2, "shotgun_shells": 3, "rifle_rounds": 5,
	"health_pack": 18, "canned_food": 8, "batteries": 6, "planks": 4, "used_planks": 2, "barricade": 14, "plywood": 5,
	"scrap_metal": 4,
}

var stock := Inventory.new()
## Set by main.gd. Without it (e.g. a trader dropped into a test scene) they never restock.
var day_night: Node
## The last day they restocked; their starting stock counts as day 1's.
var restocked_day := 1
## Optional: returns false while they can't restock (the wagon trader waits for
## the streets around the station to be clear). A missed morning is made up as
## soon as it returns true again.
var can_restock := Callable()


func _npc_ready() -> void:
	# Inspector typos (e.g. "pistol_amo") would crash the shop screen later, so
	# drop unknown ids now with a warning in the Output panel.
	_drop_unknown(buy_prices, "buy price")
	_drop_unknown(sell_prices, "sell price")
	_drop_unknown(starting_stock, "stock")
	_drop_unknown(rare_stock, "rare stock")
	for id: String in starting_stock:
		stock.add(id, starting_stock[id])
	for id: String in rare_stock:
		stock.add(id, rare_stock[id])


## Checked every physics frame; cheap. Comparing days (rather than reacting
## to the clock passing an hour) means a loaded save can't restock twice.
func _npc_physics(_delta: float) -> void:
	if day_night and day_night.day > restocked_day and day_night.hour >= restock_hour \
			and (not can_restock.is_valid() or can_restock.call()):
		restock()


func restock() -> void:
	restocked_day = day_night.day
	for id: String in starting_stock:
		var missing: int = starting_stock[id] - stock.count(id)
		if missing > 0:
			stock.add(id, missing)
	for id: String in rare_stock:
		var short: int = rare_stock[id] - stock.count(id)
		if short > 0 and randf() < rare_chance:
			stock.add(id, short)


func buy_price(id: String) -> int:
	return buy_prices.get(id, 0)


func sell_price(id: String) -> int:
	return sell_prices.get(id, 0)


## Can't trade with someone who's dead.
func can_trade() -> bool:
	return not is_dead


func interact_prompt() -> String:
	return "trade with " + display_name if can_trade() else ""


func _drop_unknown(dict: Dictionary, what: String) -> void:
	for id in dict.keys():
		if not GameData.has_item(id):
			push_warning("%s %s: unknown item id '%s' ignored. Valid ids: %s"
					% [display_name, what, id, GameData.item_ids()])
			dict.erase(id)


func own_business(main: Node) -> Array:
	return ["Trade", func() -> void: main.shop_menu.open(main.player, self)]
