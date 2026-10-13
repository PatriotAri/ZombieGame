# How to write quests

Quests are resource files you build in the Godot editor's Inspector. You don't
write code for them.

- `quests/main_story.tres` is the main story. There's exactly one.
- `quests/side/` holds the side quests. Every quest file in this folder is in
  the game.
- `quests/examples/medicine_run.tres` is a finished example side quest. The
  game doesn't load the `examples` folder; copy the file into `quests/side/` to
  try it in game.

`quests/quest_manager.gd` runs them all. You shouldn't need to open it.

## Making a side quest

1. In the FileSystem dock, right-click `quests/side/` and choose **New
   Resource...**, then pick **QuestData**. Name the file (for example
   `lost_dog.tres`).
2. Select it and fill in the Inspector:
   - **Id:** a unique name with no spaces (`lost_dog`). Saves use it, so don't
     change it later.
   - **Title** and **Description:** shown in the journal.
   - **Giver:** who offers it. This is an NPC's name exactly as the game shows
     it: `Police Chief`, `Quartermaster`, `Wagon Trader`, `Woodworker`, or a
     survivor such as `Marisol Vega`.
   - **Offer:** what the giver says when offering it (see Conversations
     below). A "!" floats over the giver while they have a quest to offer.
3. **Available:** when the giver starts offering it.
   - `from_start`: as soon as the game begins.
   - `after_main_step`: once a main story step is done. Put that step's id in
     **Available After**, for example `report` or `meet_woodworker`.
   - `after_quest`: once another quest is finished. Put its id in **Available
     After**.
   - **Can Retry:** whether it can be taken again after it fails. Abandoned
     quests can always be taken again.
4. **Failing** (optional):
   - **Time Limit Hours:** in-game hours to finish it, counted from accepting
     it.
   - **Fail If Dies:** names of NPCs the quest needs alive.
5. **Steps:** add them in order (see Steps below).
6. **Finish:**
   - **Reward Money** and **Reward Items:** given when the quest is done. Item
     ids come from `core/game_data.gd`, for example `health_pack: 1`.
   - **Complete Story:** text shown in the middle of the screen when it's done.
   - **Afterword:** what the giver says afterwards, when there's nothing else
     to talk about.
   - **Event Stories:** text shown when an event first happens while the quest
     is going. The key is the event name, the value is the text.

## Steps

Each step has an **Id** (other steps and replies refer to it), an
**Objective** (shown on the HUD and in the journal), a **Kind** and a
**Target**:

| Kind | Target | Done when |
|---|---|---|
| `go_to_place` | a Place marker's name (`Gas Station`, `Safe House`, `Police Station`, `Grocery Store`) | you're within the place's radius |
| `talk_to` | an NPC's name | you finish the step's **Dialogue** with them |
| `clear_zone` | a zone's name (`Zone 1`, ...) | no zombies are left in it |
| `event` | an event name (below) | the game reports it |

**Counts If Done Earlier** (on by default) means it's already done if it
happened before the step began. For example, if you reached the place first,
the step completes the moment it starts.

The game reports these events:
- `safe_house_reached`
- `trader_found`
- `woodworker_untied`
- `woodworker_found`
- `zone_cleared:<zone>` (for example `zone_cleared:Zone 1`)
- `reached:<place>` (for example `reached:Gas Station`)

**Talk** settings:
- **Dialogue** is what the target says on a `talk_to` step.
- **Variants** are other ways a `talk_to` step can go if an event already
  happened, such as the Chief noticing you've been to the safe house. Each
  variant has its own dialogue, the step to skip to, and a reward.
- **Reminder** is what the quest's giver says if you talk to them during a step
  that isn't about them.

**Waypoint** settings: by default the waypoint points at the NPC for `talk_to`
and the place for `go_to_place`. You can set it to a place, an NPC or a
SpawnPoint role, or to none. **Marker Label** is what the waypoint says.
**Autosave Near** autosaves the first time you get close to it.

**Story** settings:
- **Start Story** and **Complete Story** are shown big in the middle of the
  screen.
- **Reward Money** and **Reward Items** are given when the step is done.
- **Next Step** jumps to another step's id instead of going to the next one in
  the list.
- **Time Limit Hours** sets a limit for this step alone.

## Conversations

A conversation (**QuestDialogue**) is a list of **nodes**. It starts at the
first one. Each node has:
- **Lines:** shown one at a time.
- **Speaker:** empty means whoever you're talking to.
- **Replies:** each has text you say, a **Next** node id (empty ends the
  conversation), and an **Action**:
  - `accept` takes the quest being offered.
  - `decline` turns it down for now.
  - `fail` fails the quest.
- **Next:** with no replies, the node that comes next.

Reaching the end of a conversation is what "finishing" it means. That's what
completes a `talk_to` step. Declining, failing, or walking away (Esc) doesn't
finish it. An offer with no `accept` reply anywhere is accepted by hearing it
out.

The example `medicine_run.tres` offer shows branching: "What's in it for me?"
leads to the price, then **Deal** (accept) or **Not for that** (decline).

## In game

- **J** (D-pad down on a controller) opens the journal. It lists your quests
  and their steps, and lets you **Track** one (its objective and waypoint go on
  the HUD) or **Abandon** a side quest.
- Talking to someone who has quest business and also their own (trading,
  building) gives you a choice of which.
- **"!"** over someone means they have a quest to offer. **"?"** means a quest
  needs you to talk to them.
- The main story can't be abandoned and never fails.
