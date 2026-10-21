extends Node
## Everything on screen during play: the HUD and the menus, and what opens
## them when something you use asks for a screen (a container, the logbook, a
## bulletin board: Player's signals), what the HUD says about what's going on,
## the dialog for taking down a camp you built, and the death screen. main.gd
## makes it once you and the camps are there (it goes after you in the scene
## tree on purpose: Godot sends input to later nodes first, so while a menu is
## open it gets Esc/E before the pause menu and you do), then calls the setup_
## functions as the rest of the game comes up.

const Player := preload("res://characters/player/player.gd")
const DayNight := preload("res://world/day_night.gd")
const GameMap := preload("res://world/game_map.gd")
const LootSpot := preload("res://items/loot_spot.gd")
const StructurePiece := preload("res://world/structure_piece.gd")
const Survivor := preload("res://characters/npcs/survivor.gd")
const Camps := preload("res://world/camps.gd")
const Structures := preload("res://world/structures.gd")
const Zones := preload("res://world/zones.gd")
const Discoveries := preload("res://world/discoveries.gd")
const QuestManager := preload("res://quests/quest_manager.gd")
const MapSummary := preload("res://world/map_summary.gd")
const Hud := preload("res://ui/hud.gd")
const PerfOverlay := preload("res://ui/perf_overlay.gd")
const PauseMenu := preload("res://ui/pause_menu.gd")
const CraftMenu := preload("res://ui/craft_menu.gd")
const ChoiceMenu := preload("res://ui/choice_menu.gd")
const InventoryMenu := preload("res://ui/inventory_menu.gd")
const ShopMenu := preload("res://ui/shop_menu.gd")
const DialogueBox := preload("res://ui/dialogue_box.gd")
const SaveMenu := preload("res://ui/save_menu.gd")
const MapMenu := preload("res://ui/map_menu.gd")
const BackpackMenu := preload("res://ui/backpack_menu.gd")
const JournalMenu := preload("res://ui/journal_menu.gd")

var hud: Hud
var craft_menu: CraftMenu
var choice_menu: ChoiceMenu
var inventory_menu: InventoryMenu
var shop_menu: ShopMenu
var dialogue: DialogueBox
var save_menu: SaveMenu
var map_menu: MapMenu
var backpack_menu: BackpackMenu
var journal_menu: JournalMenu
var _player: Player
var _camps: Camps
var _structures: Structures


## The HUD and the menus, and what you ask of them. save_game: (path) -> bool,
## what the logbook's menu saves with.
func build(player: Player, day_night: DayNight, save_game: Callable) -> void:
	_player = player
	hud = Hud.new()
	add_child(hud)
	hud.setup(player, day_night)
	add_child(PerfOverlay.new())
	add_child(PauseMenu.new())
	craft_menu = CraftMenu.new()
	add_child(craft_menu)
	choice_menu = ChoiceMenu.new()
	add_child(choice_menu)
	inventory_menu = InventoryMenu.new()
	add_child(inventory_menu)
	shop_menu = ShopMenu.new()
	add_child(shop_menu)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	save_menu = SaveMenu.new()
	add_child(save_menu)
	map_menu = MapMenu.new()
	add_child(map_menu)
	backpack_menu = BackpackMenu.new()
	add_child(backpack_menu)
	backpack_menu.setup(player)
	player.damaged.connect(hud.flash_hurt)
	player.notify.connect(hud.show_toast)
	player.container_opened.connect(func(spot: Node) -> void: inventory_menu.open(player, spot as LootSpot))
	player.save_menu_requested.connect(func() -> void: save_menu.open(player, save_game))
	player.reading_requested.connect(func(title: String, text: String) -> void:
		choice_menu.open(player, title, text, [["Close", Callable(), true]]))
	# Getting hurt never closes a menu or a conversation: only Esc (each menu
	# handles its own) or dying does.
	for menu: Callable in [inventory_menu.close, shop_menu.close, dialogue.close, save_menu.close, map_menu.close,
			backpack_menu.close, craft_menu.close, choice_menu.close]:
		player.died.connect(menu)


## The map screen, and the toasts for where you are and what you find.
func setup_map(map: GameMap, zones: Zones, camps: Camps, discoveries: Discoveries) -> void:
	map_menu.setup(_player, zones, camps, discoveries, MapSummary.rects(get_tree(), "map_road"),
			MapSummary.buildings(map.town), MapSummary.rects(get_tree(), "map_fence"), MapSummary.streets(map.places))
	zones.zone_entered.connect(func(zone_name: String) -> void: hud.show_toast("Entering " + zone_name))
	discoveries.discovered.connect(func(names: Array[String]) -> void:
		hud.show_toast("Discovered: " + ", ".join(names)))


## The journal, and what the story puts on the HUD.
func setup_story(quests: QuestManager) -> void:
	quests.objective_changed.connect(hud.set_objective)
	quests.story_beat.connect(hud.show_story)
	journal_menu = JournalMenu.new()
	add_child(journal_menu)
	journal_menu.setup(_player, quests)
	_player.died.connect(journal_menu.close)


## Taking down a camp kit asks where its people should go (_take_down_camp).
func setup_camps(camps: Camps, structures: Structures) -> void:
	_camps = camps
	_structures = structures
	structures.camp_take_down_requested.connect(_take_down_camp)


func show_toast(text: String) -> void:
	hud.show_toast(text)


## You died: the mouse is yours again. has_save: there's a save to go back to.
func show_death(has_save: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_death(has_save)


## Taking down a camp you built: its people need somewhere else to live. For
## each, you pick another camp with room; once everyone's placed, it comes down
## and you get the camp kit back. With nowhere for someone to go, it stays up.
func _take_down_camp(piece: StructurePiece) -> void:
	var camp := _camps.camp_for_piece(piece)
	if camp == null:
		return
	var people := _camps.members(camp)
	_rehome(people, camp, piece)


func _rehome(people: Array, leaving: Camps.Camp, piece: StructurePiece) -> void:
	if people.is_empty():
		var back := _structures.take_down(piece)
		for id: String in back:
			_player.give_item(id, back[id])
		hud.show_toast("%s is packed up." % leaving.name)
		return
	var survivor: Survivor = people[0]
	var options := []
	for camp in _camps.with_room():
		if camp == leaving:
			continue
		var label := "%s  (%d / %d)" % [camp.name, _camps.population(camp), _camps.capacity(camp)]
		options.append([label, func() -> void:
			_camps.move_to(survivor, camp)
			_rehome(people.slice(1), leaving, piece), true])
	if options.is_empty():
		hud.show_toast("There's no room anywhere for %s. Make room at another camp first." % survivor.display_name)
		return
	options.append(["Never mind (keep the camp)", Callable(), true])
	choice_menu.open(_player, "Taking down " + leaving.name, "Where should %s live now?" % survivor.display_name, options)
