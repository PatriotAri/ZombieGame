# How to write quests

Quests are resource files you build in the Godot editor's Inspector. You don't
write code for them.

- `quests/main/` holds the main story. Every quest file in it is part of the
  story: it can't be abandoned and never fails. Today that's
  `westside_safe_house.tres`.
- `quests/side/` holds the side quests. Every quest file in it (subfolders
  too) is in the game.
- `quests/examples/medicine_run.tres` is a finished example side quest. The
  game doesn't load `examples/`; copy the file into `quests/side/` to try it.

`quests/quest_manager.gd` runs them all. You shouldn't need to open it.

A quest is made of **stages**, one after another. Each stage has
**objectives** (what to do now). **Conditions** are checks (has the item, a
flag's set, someone's alive); **actions** are things that happen (give money,
bring someone in). Quests point at places and people **by id**: quest markers
you put on the map, and people's ids. Nothing goes by the names the game shows.

## Making a quest

1. In the FileSystem dock, right-click `quests/side/` and choose **New
   Resource...**, then pick **Quest**. Name the file (`lost_dog.tres`).
2. Select it and fill in the Inspector:
   - **Id:** unique, no spaces (`lost_dog`). Saves go by it: don't change it
     once there are saves.
   - **Title** and **Description:** shown in the journal.
   - **Giver:** who offers it, by their id (`chief`, `quartermaster`,
     `marisol_vega`). A "!" floats over them while it's on offer. Empty: it
     starts by itself as soon as it's available.
   - **Offer:** what the giver says when offering it (a conversation, below).
     A reply with the `accept` action takes the quest; `decline` turns it down
     for now. With no `accept` reply anywhere, hearing it out takes it. A quest
     with a Giver needs an Offer: there's no other way to take it.
3. **Available:**
   - **Available When:** conditions (below). It's on offer, or starts, once
     they all hold. None: from the start. For "after the story's report", use a
     Quest condition: quest `westside_safe_house`, Reached Stage `report`.
   - **Can Retry:** it's on offer again after it fails. (An abandoned quest
     always is.)
4. **Stages:** add them in order (below). It starts at the first.
5. **Failing** (side quests only):
   - **Time Limit Hours:** in-game hours from taking it to finish it.
   - **Fail When:** conditions; it fails as soon as any of them holds (a
     Person Alive condition with Negate on: "fails if the trader dies").
   - **Fail Text:** shown as why it failed.
6. **Start and finish:**
   - **On Start, On Complete, On Fail:** actions.
   - **Reward Money** and **Reward Items** (item id: how many, the ids are the
     file names in `items/data/`: `health_pack`, `pistol_ammo`...).
   - **Complete Story:** shown big in the middle of the screen when it's done.
   - **Afterword:** what the giver (or **Afterword From**, an id) says
     afterwards, when there's nothing else to talk about.

Then press **Map Tools > Quests > Check quests** (below) to find typos and
anything the map is still missing.

## Stages

Each stage has:
- **Id:** other stages, branches and conditions go to it by this. Saves go by
  it too.
- **Journal Note:** added to the quest's page in the journal while it's here.
- **Objectives:** what to do (below). Click the array, **Add Element**, then
  **New** and pick the kind.
- **Finish When:** `all` (every objective that isn't optional; the usual) or
  `any` (as soon as one is).
- **Next:** where it goes when it's done. Empty: the next stage in the list
  (or the quest's done, after the last). `end`: the quest's done. Or a
  stage's id, to jump.
- **Branches:** checked in order when it's done; the first whose **When**
  conditions all hold picks the **Next** instead. This is how a quest goes two
  ways: the story skips ahead if you'd already been to the safe house.
- **Time Limit Hours:** for this stage alone; the quest fails if they run out.
- **Reminder** and **Reminder From:** what someone (the giver, if empty) says
  if you talk to them meanwhile ("The safe house is out west. Go.").
- **Story:** **Start Story** and **Complete Story** (shown big on screen),
  **On Start** and **On Complete** actions, and **Reward Money** and **Reward
  Items** paid when the stage is done.

An objective that's already true when its stage begins is done at once (you're
already at the place, already have the items), and a stage with nothing left to
do moves straight on.

## Objectives

Every objective has:
- **Id:** what saves call it. Empty: its place in the list (`1`, `2`...).
- **Text:** shown on the HUD, in the journal and on the map. `{count}` and
  `{total}` show progress for the kinds that count: "Kill zombies at the farm
  ({count}/{total})".
- **Optional:** an extra; the stage doesn't wait for it.
- **Leads To:** in a stage that finishes on `any`: the stage to go to when it's
  this one that's done.
- **When:** conditions that must hold too before it counts (going to where the
  trader stands only counts once the trader's there).
- **Show On Map** and **Map Label:** marked on the map screen while it's the
  tracked quest's (the label defaults to the Text).

| Kind | Settings | Done when |
|---|---|---|
| **Go To** | Marker; Radius (for a point marker) | you're in the marker's area, or within Radius of a point |
| **Talk To** | Npc; Dialogue; Choice Label | you get to the end of their conversation (not if you walk off or decline). Empty dialogue: as soon as you talk to them. A "?" floats over them |
| **Collect** | Item; Count; Marker (for the map) | you have that many on you. Nothing's taken |
| **Deliver** | Npc; Item; Count; Dialogue; Choice Label | you have them and talk to the person: they're handed over |
| **Kill** | Count; Zombie Kind (empty: any); Near (a marker) and Radius; Only Yours | you've killed that many since the stage began |
| **Survive** | Until Hour, or Hours; Stay In (an area marker); Leaving Fails | the hour comes round, or the hours pass (with Stay In, only time spent there counts) |
| **Use** | Marker (a usable one) | you use it. It offers itself only while this is going |
| **Event** | Event; Match; Count; Counts If Earlier; Marker | the event happens (Count times). Match narrows it, below |
| **Wait For** | Conditions; Marker | the conditions all hold |

## Conditions

Every condition has **Negate**: it holds when the check doesn't ("hasn't got
the key", "isn't alive").

| Kind | Settings | Holds when |
|---|---|---|
| **Has Item** | Item; Count | you have at least that many on you |
| **Quest** | Quest; Status (`done`, `failed`, `active`, `not started`, `any`); Reached Stage | that quest is so, and (if set) has been at that stage at some point |
| **Flag** | Flag; At Least | the flag is at least that (flags start at 0) |
| **Time** | From Hour; To Hour; From Day | the time is between the hours (20 to 5 is the night), from that day on |
| **Person Alive** | Npc | they're in the world and alive |
| **Happened** | Event; Match | the event has happened at some point. Kills, items gained or lost, hours and leaving areas aren't remembered: use an objective for those |
| **In Area** | Marker (an area one) | you're in it right now |

## Actions

| Kind | Settings | Does |
|---|---|---|
| **Give** | Items; Money | gives them to you |
| **Take** | Items; Money | takes them (as much as you have) |
| **Set Flag** | Flag; Value; Add | sets a flag (or adds to it). Flags are saved |
| **Start Quest** | Quest | starts it now, offered or not |
| **Fail Quest** | Quest (empty: this one); Why | fails it (never the main story) |
| **Story** | Text | shows it big in the middle of the screen |
| **Noise** | Marker; Radius | every zombie and bandit within Radius comes to look |
| **Spawn Person** | Person (a person file); At (a marker) | they turn up there, once you're away from it (so you don't see them pop in) |
| **Spawn Scene** | Scene; At | something turns up there (the trader's wagon), once you're away |
| **Move Person** | Npc; To (a marker) | they're there instead (and stay), once you're away from both places |
| **Remove Person** | Npc | they leave for good, once you're away |
| **Autosave** | | autosaves as soon as nothing's after you |

People and things a quest brings in, moves or sends off are saved.

## Conversations

A conversation (**QuestDialogue**) is a list of **nodes**. Each node has:
- **Id:** replies and Next lead to it by this. Every new node is called
  `start`: rename all but the first.
- **Speaker:** empty means whoever you're talking to.
- **Lines:** shown one at a time.
- **Replies:** each has the **Text** you say, a **Next** node id (empty ends
  the conversation), an **Action**, **When** (it's offered only while these
  conditions hold) and **Actions** (done when you pick it: give an item, set a
  flag...). The Action is one of:
  - `accept`: takes the quest being offered.
  - `decline`: turns it down for now, and ends the conversation.
  - `fail`: fails the quest, and ends the conversation.
  - `join`: for survivors (see `HOW_TO_ADD.md`).
- **Next:** with no replies (or none whose When holds), the node that comes
  next. Empty ends the conversation.
- **Start When:** the conversation starts here instead of at the first node
  while these hold (the first node in the list whose do). The Chief says
  something else once you've been to the safe house this way.

Getting to the end of a conversation is what "finishing" it means: that's
what completes a Talk To. Declining, failing or walking away (Esc) doesn't.

The example `medicine_run.tres` offer branches: "What's in it for me?" leads to
the price, then **Deal** (accept) or **Not for that** (decline).

## People and places

**People** go by their id (**Npc Id**). Someone on the map comes from a person
file in `characters/npcs/people/` (**PersonData**: id, name, scene, look, and
**Talk**, what they say when there's nothing else). Put them on the map with
**Map Tools > Quests > New person**; with **Start Here** off they aren't there
until a quest's Spawn Person brings them. Turn on **Captive** and they're tied
to a post until you untie them: they say their file's **Untie Talk**, and
quests hear `person_freed`. Survivors you can recruit have their own files
(`characters/npcs/survivors/`), and their **Id** is what quests call them.

**Places** are quest markers: **Map Tools > Quests > New quest marker**, then
its **Marker Id** and **Kind** (`point`, `area` or `usable`). See
`HOW_TO_MAP.md`, section 12, for the markers the story needs.

## Events

What Event objectives, Happened conditions and Match go by (each has data, and
every key in **Match** must equal the event's: `npc_died` with Match
`{"npc_id": "chief"}` is the Chief dying):

| Event | Data |
|---|---|
| `zombie_killed` | kind, by_player |
| `npc_died` | npc_id, name, by_player |
| `player_died` | cause |
| `item_gained`, `item_lost` | item, amount |
| `container_opened` | town_id, label |
| `area_entered`, `area_left` | marker |
| `object_used` | marker |
| `place_discovered` | place |
| `hour_passed` | hour, day |
| `flag_set` | flag, value |
| `quest_started`, `quest_completed`, `quest_failed` | quest |
| `stage_reached` | quest, stage |
| `person_freed` | npc_id |

## Checking and trying quests

- **Map Tools > Quests > Check quests** checks every quest against the map
  you have open, without playing. It lists (in the panel, and all of it in the
  Output panel): markers and people a quest names that aren't on the map, the
  wrong kind of marker, items, zombie kinds, events or quests that don't exist,
  stages and conversation nodes a Next leads to that aren't there, stages
  nothing leads to, and conversations that can't get to an end. Run it after
  every change.
- **F4** in game (playing from the editor) opens the quest debug panel: pick a
  quest to see its stage and objectives, then **Start**, **Go to stage**,
  **Count as done** (an objective), **Finish**, **Fail**, **Reset** or
  **Track** it. Below: set a flag, give yourself items or money, and go
  straight to any quest marker. The game is paused while it's open. It isn't
  in release exports.
- The tests play quests through on test maps (`tests/story_test.gd` plays the
  whole story; `tests/README.md` says how to run them).

## In game

- **J** (D-pad down on a controller) opens the journal: your quests, each
  one's note and objectives so far. **Track** one to show its objectives on
  the HUD and the map screen, or **Abandon** a side quest (whoever gave it
  offers it again).
- The map screen (**M**) marks where the tracked quest's objectives are.
  Nothing is marked in the world itself but the "!" and "?" over people.
- **"!"** over someone means they have a quest to offer. **"?"** means a quest
  needs you to talk to them.
- Talking to someone with quest business and their own (trading, building)
  gives you a choice of which.
