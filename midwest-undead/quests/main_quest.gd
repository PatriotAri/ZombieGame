extends Node
## The main storyline, as a small state machine of stages:
##
##   TALK_TO_CHIEF    -> the Chief explains the Westside safe house has gone silent
##   REACH_SAFE_HOUSE -> cross town to it; arriving reveals it's been overrun
##   REPORT_BACK      -> tell the Chief; he pays you
##   WAIT_FOR_NEXT    -> end of the current story (more quests go here later)
##
## It owns the objective text (shown on the HUD) and a waypoint marker you can
## see through walls. To add the next chapter, add a stage, its lines, and what
## moves it forward, following the same pattern.

signal objective_changed(text: String)
## A big story moment shown in the middle of the screen.
signal story_beat(text: String)

enum Stage { TALK_TO_CHIEF, REACH_SAFE_HOUSE, REPORT_BACK, WAIT_FOR_NEXT }

const CHIEF := "Police Chief"
const REWARD_MONEY := 100
const REWARD_AMMO := 14
const MARKER_HIDE_DISTANCE := 6.0 # hide the marker once you're basically there

const INTRO_LINES: Array[String] = [
	"Good, you're up. Listen. We've lost contact with the Westside safe house.",
	"Eleven people holed up there. Families, mostly. They checked in on the radio every night like clockwork.",
	"Three nights ago they missed the call. Nothing since.",
	"Could be a dead battery. Could be worse. I can't spare a guard off the towers to find out.",
	"It's on the far west end of the cross street, past Main. Get over there, see what happened, and come back and tell me.",
	"Trade with the Quartermaster if you need supplies. And keep it quiet out there. Gunfire brings every one of them for blocks.",
]
const REMINDER_LINES: Array[String] = [
	"The safe house is on the west end of the cross street, past Main. Go. And come back in one piece.",
]
const SAFE_HOUSE_DISCOVERY := "The barricade is torn open. The windows are smashed in.\nNobody answered the radio because nobody is left."
const REPORT_LINES: Array[String] = [
	"...You're back. What did you find?",
	"Overrun. All of them?",
	"Damn it. I knew those people. The Harlans. Old Mrs. Pruitt. The Okafor kids.",
	"If the Westside barricades couldn't hold, nothing in this town is as safe as we've been telling ourselves.",
	"Here. You earned this, and then some. Rest up while you can.",
	"I need to think about our next move. I'll have work for you soon.",
]
# Talking to the Chief for the first time after you've already found the safe
# house on your own: he pays you straight away instead of sending you there.
const ALREADY_BEEN_LINES: Array[String] = [
	"Good, you're up. Listen. We've lost contact with the Westside safe house, and I need someone to...",
	"...Hold on. You've got that look. You've already been out west, haven't you?",
	"Overrun. All eleven of them?",
	"Damn it. I was about to send you out there to find exactly that.",
	"You saved me a day of wondering, and yourself a trip. Here. You've earned this.",
	"I need to think about our next move. I'll have work for you soon.",
]
const IDLE_LINES: Array[String] = [
	"Still working out what comes next. Keep your head down, and keep that gun clean.",
]

var stage := Stage.TALK_TO_CHIEF
## True once you've seen the overrun safe house, whether or not the Chief sent you.
var safe_house_investigated := false
## Stages that have already been autosaved near their objective (so it happens once each).
var autosaved_stages: Array[int] = []
var player: Node3D
var chief: Node3D
var safe_house_point := Vector3.ZERO
var dialogue: Node # dialogue_box.gd
var marker: Label3D


func setup(the_player: Node3D, the_chief: Node3D, safe_house: Vector3, dialogue_box: Node) -> void:
	player = the_player
	chief = the_chief
	safe_house_point = safe_house
	dialogue = dialogue_box

	# Waypoint: floats over the current destination, drawn on top of everything
	# and the same size on screen at any distance.
	marker = Label3D.new()
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0012
	marker.font_size = 32
	marker.outline_size = 10
	marker.modulate = Color(1.0, 0.85, 0.35)
	add_child(marker)
	_set_stage(Stage.TALK_TO_CHIEF)


func objective_text() -> String:
	match stage:
		Stage.TALK_TO_CHIEF:
			return "Talk to the Police Chief"
		Stage.REACH_SAFE_HOUSE:
			return "Find out what happened at the Westside safe house (west end of the cross street)"
		Stage.REPORT_BACK:
			return "Report back to the Police Chief"
	return ""


## The Chief was spoken to. What he says depends on the stage.
func talk_to_chief() -> void:
	match stage:
		Stage.TALK_TO_CHIEF:
			if safe_house_investigated:
				dialogue.start(CHIEF, ALREADY_BEEN_LINES, player, _reward)
			else:
				dialogue.start(CHIEF, INTRO_LINES, player, _set_stage.bind(Stage.REACH_SAFE_HOUSE))
		Stage.REACH_SAFE_HOUSE:
			dialogue.start(CHIEF, REMINDER_LINES, player)
		Stage.REPORT_BACK:
			dialogue.start(CHIEF, REPORT_LINES, player, _reward)
		Stage.WAIT_FOR_NEXT:
			dialogue.start(CHIEF, IDLE_LINES, player)


## Called when you walk into the safe house grounds. Works whether the Chief sent
## you or you got there first; either way the discovery only happens once.
func reached_safe_house() -> void:
	if safe_house_investigated:
		return
	if stage == Stage.REACH_SAFE_HOUSE:
		_set_stage(Stage.REPORT_BACK)
	elif stage != Stage.TALK_TO_CHIEF:
		return
	# (Still at TALK_TO_CHIEF: you went before being asked. The objective stays
	# "talk to the Chief", and he'll pay you as soon as you do.)
	safe_house_investigated = true
	story_beat.emit(SAFE_HOUSE_DISCOVERY)
	# You stumbled in on them: everything inside comes to see what made that noise.
	get_tree().call_group("noise_listeners", "hear_noise", safe_house_point, 30.0)


func _reward() -> void:
	player.set("money", int(player.get("money")) + REWARD_MONEY)
	player.call("give_item", "pistol_ammo", REWARD_AMMO)
	player.emit_signal("notify", "+$%d  ·  +%d pistol rounds" % [REWARD_MONEY, REWARD_AMMO])
	_set_stage(Stage.WAIT_FOR_NEXT)


## Where the current objective is (the waypoint), or Vector3.INF if there isn't one.
func objective_position() -> Vector3:
	return _marker_target()


## Everything the save file needs to know about the story.
func save_state() -> Dictionary:
	return {"stage": stage, "safe_house_investigated": safe_house_investigated,
			"autosaved_stages": autosaved_stages}


## Jump straight to the saved point in the story (no dialogue, no rewards).
func load_state(data: Dictionary) -> void:
	safe_house_investigated = bool(data.get("safe_house_investigated", false))
	autosaved_stages.clear()
	for s in data.get("autosaved_stages", []):
		autosaved_stages.append(int(s))
	var saved := int(data.get("stage", 0))
	if saved >= 0 and saved < Stage.size():
		_set_stage(saved as Stage)


func _set_stage(new_stage: Stage) -> void:
	stage = new_stage
	objective_changed.emit(objective_text())


func _process(_delta: float) -> void:
	var target := _marker_target()
	var dist := INF if target == Vector3.INF else player.global_position.distance_to(target)
	marker.visible = dist > MARKER_HIDE_DISTANCE and dist != INF
	if marker.visible:
		marker.global_position = target + Vector3(0, 3.2, 0)
		var place := "Safe house" if stage == Stage.REACH_SAFE_HOUSE else CHIEF
		marker.text = "%s\n%d m\n▼" % [place, roundi(dist)]


func _marker_target() -> Vector3:
	match stage:
		Stage.TALK_TO_CHIEF, Stage.REPORT_BACK:
			return chief.global_position
		Stage.REACH_SAFE_HOUSE:
			return safe_house_point
	return Vector3.INF
