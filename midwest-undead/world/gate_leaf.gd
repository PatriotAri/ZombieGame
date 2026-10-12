extends StaticBody3D
## The swinging part of a fence gate you built. Press interact on it to open or
## close the gate (the posts either side are the piece itself: interact on those
## takes the whole gate down). Zombies can't break it.

var piece: Node3D # the gate (structure_piece.gd)


func interact_prompt() -> String:
	return "close the gate" if piece.gate_open else "open the gate"
