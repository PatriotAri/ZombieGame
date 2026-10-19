extends SceneTree
## Builds the stand-ins: simple shapes that look like what they are, until
## there are models (HOW_TO_MODEL.md, "Props"). Run it from the project folder
## to rebuild them after changing this:
##   godot --headless --path . -s res://world/props/make_props.gd
## It writes:
##   world/kit/furniture/standins/<name>.tscn  furniture: each furniture scene's
##       first model (stretched to the piece's Size)
##   world/kit/furniture/<name>.tscn           the newer furniture pieces' own
##       scenes, only if missing (so their settings, once changed, are kept)
##   world/props/<name>.tscn                   a KitProp with its stand-in under
##       StandIn: things you build, camp props, doors, windows, planks. Set
##       Models on one of those to swap in a model (running this again keeps
##       the Models you set).
## Everything faces -Z like the rest of the kit, sits on its origin unless
## said otherwise, and is the size the game makes the thing. Each kind of prop
## is its own script, on prop_builder.gd's building blocks: props_furniture.gd,
## props_built.gd, props_camp.gd and props_openings.gd.

const SECTIONS: Array[Script] = [
	preload("res://world/props/props_furniture.gd"),
	preload("res://world/props/props_built.gd"),
	preload("res://world/props/props_camp.gd"),
	preload("res://world/props/props_openings.gd"),
]


func _initialize() -> void:
	var made := 0
	for section in SECTIONS:
		var builder: RefCounted = section.new()
		builder.call("make")
		made += int(builder.get("_made"))
	print("props: %d scenes saved" % made)
	quit()
