extends HumanNPC
## The Police Chief: runs the station and gives you your main quests.
## What he says depends on where you are in the story; main_quest.gd holds the
## lines, he just offers to talk.

func interact_prompt() -> String:
	return "talk to " + display_name
