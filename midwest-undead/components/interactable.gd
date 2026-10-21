class_name Interactable
extends Node
## What makes something usable: look at its parent and press interact. The
## player finds this node on whatever it's looking at, shows "E: " + its
## prompt, and on interact emits interacted. What happens then is up to whoever
## listens: the thing itself (a door opens), or what built it (structures.gd
## takes a fence down).
##
## Things made in code add one at the end of their _ready():
##     Interactable.attach(self, interact_prompt).interacted.connect(_on_interacted)
## (at the end, so code that counts the children doesn't count it). Whatever
## listens from outside connects once the thing is in the tree:
##     Interactable.of(piece).interacted.connect(...)
## In a scene, add an Interactable node under the thing, type its Prompt and
## connect interacted in the Node dock.

signal interacted(actor: Node3D)

const META := &"interactable"

## Shown after the key ("open the door"). Empty: nothing to do just now.
@export var prompt := ""
## When the words change (a door open or shut): returns them. Used instead of
## Prompt when set.
var prompt_source := Callable()

var _host: Node


## The Interactable under node, or null if it has none.
static func of(node: Node) -> Interactable:
	# (get_meta(META, null) would complain: a null default counts as none.)
	if node == null or not node.has_meta(META):
		return null
	return node.get_meta(META) as Interactable


## Adds one under host whose prompt comes from prompt_source. Returns it.
static func attach(host: Node, source: Callable) -> Interactable:
	var it := Interactable.new()
	it.name = "Interactable"
	it.prompt_source = source
	host.add_child(it)
	return it


## What the prompt says now; "" if there's nothing to do.
func get_prompt() -> String:
	return prompt_source.call() if prompt_source.is_valid() else prompt


## Use it. Does nothing while the prompt is empty.
func interact(actor: Node3D) -> void:
	if get_prompt() != "":
		interacted.emit(actor)


# The parent knows it has one from the moment it's added (before it's in the
# tree), so of() works on things built in code right away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_host = get_parent()
		_host.set_meta(META, self)
	elif what == NOTIFICATION_UNPARENTED:
		if is_instance_valid(_host) and of(_host) == self:
			_host.remove_meta(META)
		_host = null
