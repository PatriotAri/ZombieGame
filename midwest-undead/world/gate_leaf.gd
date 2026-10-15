extends StaticBody3D
## The swinging part of a fence gate you built. Press interact on it to open or
## close the gate (the posts either side are the piece itself: interact on those
## takes the whole gate down). Zombies bash it while it's shut, the same as the
## rest of the gate (structure_piece.gd).

var piece: Node3D # the gate (structure_piece.gd)


func interact_prompt() -> String:
	return "close the gate" if piece.gate_open else "open the gate"


func can_be_bashed() -> bool:
	return not piece.gate_open and piece.call("can_be_bashed")


func bash(damage: float) -> void:
	if can_be_bashed():
		piece.call("bash", damage)
