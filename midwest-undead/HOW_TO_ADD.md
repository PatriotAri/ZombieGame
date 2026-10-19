# How to add items, weapons, loot, zombies and survivors

Each of these is a resource file you make and edit in the Godot editor's
Inspector. You don't write code for them. The game picks up every file in the
folder, so adding one is making a file.

To make one, right-click the folder in the FileSystem dock, choose **New
Resource...**, and pick the type named below. The quickest way to get a working
one is to duplicate an existing file (right-click, **Duplicate...**) and change
it.

| What | Folder | Type |
|---|---|---|
| Items | `items/data/` | ItemData |
| Guns and melee weapons | `items/data/` | WeaponData |
| Loot tables | `items/loot/` | LootTable |
| Zombie kinds | `characters/zombie/kinds/` | ZombieKind |
| Survivors | `characters/npcs/survivors/` | SurvivorData |

Ids and names are how everything else finds a file: saves, traders, loot
tables, recipes, quests and markers. Don't change one once it's in use.

## Items (`items/data/`, ItemData)

- **Id:** unique, no spaces (`canned_food`).
- **Display Name:** what the game calls it.
- **Use:** what the use button does while you hold it:
  - `none`: it can't be held. It just sits in your inventory (ammo, batteries,
    materials).
  - `heal` / `eat`: used up like a health pack / canned food.
  - `board` / `barricade` / `build`: like planks / a barricade / a building
    piece. A new `build` item also needs code in `world/structures.gd`.
  - `plate`: like sheet metal: covers the fence or gate you're looking at.
- **Order:** where it comes in inventory lists (lower first). Today's items use
  10, 20, 30...
- **Looks:**
  - **Model:** a scene of what it looks like on the ground. It sits on the
    ground at the scene's origin. It's also used in your hands for things you
    use up. If there's no model, the item is a box of **Size** (meters) and
    **Color**. Size is also the pickup zone, at least 0.5 x 0.3 x 0.5.
  - `items/models/health_pack.tscn` is an example.

A new item is in the game, but nothing hands it out yet. Add it to:
- a loot table (below);
- a trader: their **Starting Stock**, **Buy Prices** and **Sell Prices** in the
  Inspector. Open their scene and select the root node. The Quartermaster is
  `characters/npcs/shopkeeper.tscn` and the wagon trader is
  `characters/npcs/wagon_trader.tscn`;
- a container's **Fixed Items**;
- a quest reward.

## Weapons (`items/data/`, WeaponData)

A weapon is an item (everything above) plus how it fights. **Weapon Kind** is
`gun` or `melee`.

- **In your hands:**
  - **Held Model:** the scene in front of the camera. Copy
    `items/models/pistol_held.tscn` to start. No model: a box like on the
    ground. A model can have parts the game animates (a slide, a pump, a
    magazine...) and its own animations: see `HOW_TO_MODEL.md`.
  - **Held Position:** where it sits (x right, y up, -z ahead of the camera).
    Guns use (0.25, -0.22, -0.45); the crowbar uses (0.35, -0.35, -0.55).
  - **Draw Time:** seconds to bring it up when you switch to it. You can't use
    it until it's up. The pistol takes 0.3; the rifle takes 0.5.
- **Hitting (both kinds):**
  - **Damage:** per hit; for a gun, per pellet. Headshots do 2.5x.
  - **Reach:** how far a shot goes, or how far a swing reaches (meters).
  - **Cooldown:** seconds between shots or swings.
  - **Knockback:** how hard a hit shoves a zombie back.
  - **Noise:** meters. Zombies this close hear it: a gun on every shot, a melee
    weapon when it hits. The pistol is 40.
- **Gun:**
  - **Ammo:** the item id it loads.
  - **Magazine:** rounds it holds.
  - **Pellets:** shots per trigger pull (the shotgun has 9).
  - **Spread / Aimed Spread:** degrees off where you point, from the hip and
    while aiming.
  - **Reload Time.**
  - **Aim FOV:** zoom while aiming (75 is no zoom).
  - **Scope:** aiming past 40 degrees looks through a scope.
  - **Kick:** how far the gun jerks up on each shot.
  - **Sound:** a sound name from `sounds/`, with its volume and pitch.
- **Melee:**
  - **Stamina Cost:** stamina each swing takes.
  - **Salvages:** it can pry things apart for materials (hold interact), like
    the crowbar.
  - **Digs:** it digs through a mine's cave-ins (hold interact), like the
    pickaxe.

Fists aren't a file: they're what you have with empty hands.

## Loot tables (`items/loot/`, LootTable)

A container's **Loot Table** setting names a table (the file's name without
`.tres`). The list in the Inspector shows every table in the folder.

At the start of each new game, every **Roll** in the container's table happens
with its **Chance** (0-1). A roll that happens gives one of its **Items**,
picked evenly if there are several. Each item (LootPick) is an **Item** id and
an amount from **Min Amount** to **Max Amount**.

To make something findable, add a roll to each table it should turn up in. For
example, a baseball bat at 5% in `standard`:
1. Open `standard.tres` and add an element to **Rolls**.
2. Make it a **New LootRoll** and set its **Chance** to 0.05.
3. Add an element to its **Items**, make it a **New LootPick**, and set
   **Item** to `baseball_bat` with min and max 1.

## Zombie kinds (`characters/zombie/kinds/`, ZombieKind)

Every new zombie, at the start and arriving later, rolls a kind:
- **Spawn Chance** is the chance (0-1) that a zombie is this kind.
- The kind with **Fills The Rest** (the walker) is whatever's left over.
  Exactly one kind should have it.

**Body:**
- **Model:** its body, a character scene (see `HOW_TO_MODEL.md`). Empty: the
  mannequin stand-in.
- **Health.**
- **Min / Max Speed:** each zombie picks a walking speed in this range (m/s).
  You walk at 4. Anything over 3 m/s plays the running animation.
- **Hunt Speed:** speed while chasing someone. 0 means its walking speed. The
  runner's is 7.
- **Posture:** `crawling` lies flat like the crawler. Chest-height shots go over
  it, and its head is at the front, near the ground.
- **Body Scale:** stretches it. (0.75, 1, 0.75) looks thin. Each zombie is also
  a few percent bigger or smaller at random.
- **Skin Color:** leave it fully transparent for the usual skin. Each zombie's
  is a little lighter or darker; shirts and pants are random.
- **Voice Pitch:** its groans; 1 is normal, higher is shriller.

## Survivors (`characters/npcs/survivors/`, SurvivorData)

- **Display Name:** how the game shows them. Quests (a `talk_to` step's target)
  and markers go by it too.
- **Job:**
  - `none`: they work a garden plot or a bench at their camp, or stand guard on
    a guard post.
  - `machinist`: they make benches once the woodworker's at the station.
- **Model:** optional, their own model (see `HOW_TO_MODEL.md`). Empty: the one
  every survivor has.
- **Outfit Color, Skin Color.**
- **Talk:**
  - **Join Talk:** a conversation, the same as in quests (see `QUESTS.md`).
    Give it a reply with the `join` action and picking that brings them to a
    camp. A `decline` reply leaves them where they are for now. With no `join`
    reply anywhere, hearing them out brings them.
  - **Base Talk:** optional. What they say at their camp before their work menu.
  - **Base Line:** what they say over their work menu.

Then put their SpawnPoints on the map (world/map/map.tscn) with **Person** set to their name
(see `HOW_TO_BUILD.md`):
- **survivor:** where you find them. Put it in a house.
- **survivor_home:** optional. Their own spot at the police station. Without
  one, they stand round whichever camp they live at.

When they join, they head to a base camp with room. If more than one has room,
you pick which. If every camp is full, they stay put and say so.
