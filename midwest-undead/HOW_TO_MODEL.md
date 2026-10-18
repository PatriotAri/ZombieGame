# How to add models and animations

Weapons in your hands, zombies and people work with or without a model.
Without one, a weapon is today's box gun, and a zombie or a person is the
mannequin: a plain stand-in with a real skeleton and rough animations. You can
swap a model in whenever you have one, and nothing else has to change.

So far this covers **weapons in your hands** (first person), **zombies** and
**people** (everyone who isn't a zombie). Props and buildings come later.

## The rules every model follows

- **1 unit = 1 meter.** In Blender, keep the scene's unit scale at 1.0.
- **Weapons face -Z** in Godot. In Blender that's +Y forward, and the glTF
  exporter turns it for you (leave **+Y Up** ticked).
- **Characters face +Z**: the way Blender, Mixamo and the glTF format leave them.
  The game turns them round.
- **A weapon's origin** is where your hand holds it: the grip of a gun, the
  handle of a melee weapon. Recoil and swings turn the weapon about this point.
- **Real size.** A pistol is about 20 cm long and a shotgun about 1 m.
- **Export as `.glb`** (glTF binary). It brings meshes, materials, textures and
  animations in one file.

## Detail budget (PS3 era, for a GTX 1050 Ti)

| What | Triangles | Textures |
|---|---|---|
| Gun or melee weapon in your hands | 5,000 - 15,000 | 1024 or 2048 px: color, normal, roughness/metal |
| The same item lying on the ground | under 3,000 | 512 px |
| A zombie or person | 8,000 - 15,000 | 2048 px: color, normal, roughness |

Weapons in your hands are only drawn one at a time and always close up, so they
get the most detail. Characters get simpler versions further away
automatically (LODs, see below), which a horde of 100+ needs.

## Getting a model in

1. Put the `.glb` (and its textures, if they're separate files) in
   `items/models/`. Godot imports it on its own.
2. Click the `.glb` in the FileSystem dock and open the **Import** tab:
   - **Meshes > Generate LODs:** on (the default). Godot makes simpler versions
     for when it's far away.
   - Textures are compressed for the graphics card by default. Leave that on:
     it keeps them small in video memory.
   - If it came in at the wrong size, set **Root Scale** here, not in the scene.
   - Click **Reimport** after changing anything.
3. Make the scene the game uses. Right-click the `.glb` and choose **New
   Inherited Scene**. Save it as `items/models/<name>_held.tscn`.
4. In that scene, add the markers it needs (see the next section). For a gun,
   that means at least a **MuzzleFlash**: copy it from `pistol_held.tscn`.
5. Open the weapon's file in `items/data/` (for example `pistol.tres`). Set
   **Held Model** to your new scene. Then adjust:
   - **Held Position:** where it sits on screen.
   - **Draw Time:** seconds to bring it up when you switch to it.
6. Run the game and look at it. Fix the position, then try aiming, reloading
   and sprinting.

## Parts the game moves for you

If a model has no animations, the game moves its parts by name. The names must
match exactly. A part can be anywhere in the model, and every part is optional.

| Name | What it is | What happens |
|---|---|---|
| `Slide` | pistol slide | Snaps back on each shot. Stays back when the gun's empty, until you reload. |
| `Pump` | shotgun fore-end | Racks back and forward after each shot. |
| `Bolt` | rifle bolt and handle | After each shot it lifts, pulls back, pushes forward and drops. It's open while you reload. **Put its origin on the barrel's line**, because it turns around its origin to lift. |
| `Magazine` | box magazine | Drops out and a fresh one goes in when you reload. |
| `LoadingPort` | a **Marker3D** where rounds go in | With no Magazine, rounds go in here one at a time when you reload. They come from the marker's -Y side, so turn the marker upside down for a gun loaded from the top (see `rifle_held.tscn`). |
| `MuzzleFlash` | an **OmniLight3D** at the muzzle | Lights up for a moment on each shot. |
| `Sight` | a **Marker3D** at the rear sight | When aiming, this point lines up with the middle of the screen, so you look down the sights. Without one, the gun comes up below the middle. |

**Parts must be separate objects.** In Blender, the slide, magazine and so on
each need to be their own object, named as in the table. If the gun is one
single mesh, nothing can move on its own.

The box guns use these parts: `pistol_held.tscn` (Slide, Magazine),
`shotgun_held.tscn` (Pump, LoadingPort) and `rifle_held.tscn` (Bolt,
LoadingPort).

## Your own animations

A model can bring its own animations made in Blender. Name the actions:

| Name | Plays when | Fitted to |
|---|---|---|
| `draw` | you switch to it | its Draw Time |
| `holster` | you switch away from it | 0.15 s |
| `fire` | each shot | sped up if it's longer than the gun's Cooldown |
| `reload` | reloading | its Reload Time |
| `swing` | a melee hit | sped up if it's longer than its Cooldown (the hit lands 0.08 s in) |

How it works:
- Godot puts them in an **AnimationPlayer** when it imports the `.glb`.
- Names with a prefix also work, such as `Armature|reload`.
- Each animation is sped up or slowed down to fit the game's time. So a 2-second
  reload animation on a 1.6-second reload plays a bit faster.
- An animation the model has replaces the game's own version for that action;
  everything else still uses the game's. So you can make just `reload` and keep
  the rest.
- Recoil, sway and walking bob always come from the game, on top of any
  animation.

Exporting from Blender:
1. Choose **File > Export > glTF 2.0**, with format **glTF Binary (.glb)**.
2. Under **Animation**, tick **Animation** and set **Mode** to **Actions**.
3. Keep each action short and ending where it started, so the next one picks up
   cleanly.

## How it moves (tuning)

Open `characters/player/player.tscn` and select **Camera3D/Hands**. In the
Inspector:
- **Sway:** how much things lag behind as you turn, and the most they lag.
- **Bob:** the walking bob's size and pace, and how steady it is while aiming.
- **Poses:**
  - **Sprint Tilt:** how far a weapon turns away while you sprint or swim.
  - **Landing Dip:** how hard landing from a jump dips it.

The code is in:
- `characters/player/hands.gd`: switching weapons, sway, bob and poses.
- `items/held_model.gd`: one weapon's animations.

## Zombies (characters)

A zombie kind (`characters/zombie/kinds/`, see `HOW_TO_ADD.md`) has a **Model**
setting. Leave it empty and its zombies are the mannequin
(`characters/mannequin/mannequin.tscn`).

### What a character model needs
- **A humanoid skeleton**: hips, spine, chest, neck, head, both arms (upper arm,
  forearm, hand) and both legs (thigh, shin, foot). Mixamo characters and
  Blender's Rigify rigs have one.
- **About 1.8 m tall**, standing on its origin (the origin at its feet), facing
  +Z.
- **Export as `.glb`**, skeleton and skin included.

### Getting it in
1. Put the `.glb` in `characters/zombie/models/` (make the folder).
2. Double-click it to open the **Advanced Import Settings** and select the
   skeleton (**Skeleton3D**). On the right, under **Retarget**:
   - **Bone Map:** choose **New BoneMap**, then set its **Profile** to **New
     SkeletonProfileHumanoid**. Godot matches the bones by their names. Check
     the dots on the figure: each should be matched to a bone (green). Click
     any that aren't and pick the bone yourself.
   - Leave **Rest Fixer > Overwrite Axis** and **Fix Silhouette** on.

   Click **Reimport**. This renames the bones to Godot's standard names (Hips,
   Spine, LeftUpperArm...) and calls the skeleton `GeneralSkeleton`. The game
   finds things by those names.
3. Right-click the `.glb` and choose **New Inherited Scene**. Save it as
   `characters/zombie/models/<name>.tscn`.
4. Open the zombie kind's file and set **Model** to that scene.
5. Run the game.

### Animations
The game plays these by name. A model's own animations are used first; for any
it doesn't have, it borrows the mannequin's.

| Name | When | Notes |
|---|---|---|
| `idle` | standing around | loops |
| `walk` | walking | loops; one cycle (two steps) covers 1.2 m, and it's sped up or slowed to match how fast the zombie walks |
| `run` | running (over 3 m/s) | loops; one cycle covers 2.8 m |
| `attack` | biting someone in reach | loops |
| `bash` | beating on a door, window or fence | loops |
| `hit_head`, `hit_body`, `hit_legs` | flinching from a hit there | plays once (about 0.4 s) |
| `climb` | climbing in through a window | plays once, fitted to the 1.5 s climb |
| `crawl_idle`, `crawl`, `crawl_attack`, `crawl_hit` | the same, for crawlers | `crawl` covers 0.6 m per cycle |

- **Mixamo animations:** download each one **Without Skin**. Import it with the
  same Humanoid bone map as above. In its Advanced Import Settings, select the
  animation and save it to a file. Then, in your model's scene, open the
  **AnimationPlayer**, and use **Animation > Manage Animations** to load those
  files, named as in the table.
- **Borrowing the mannequin's:** this works because the mannequin is built like
  a model imported with the Humanoid bone map. If borrowed animations look
  twisted on your model, it was imported without the bone map (step 2), or give
  it its own animations.

### What happens on its own
- **Ragdoll:** when it dies, its body goes limp and falls by physics. The
  physics bodies are made from the bone names, so there's nothing to set up.
- **Headshots:** a small hitbox follows the **Head** bone.
- **Blood:** the splatter on the ground and walls, and the marks on bodies,
  use the images in `effects/blood/` (`splat_1.png` to `splat_3.png`). Swap in
  your own: square, transparent background, same names.
- **Colors:** the mannequin gets random skin, shirt and pants colors. A real
  model keeps its own textures (only models using
  `characters/mannequin/body.tres` get random colors). Every zombie is also a
  few percent bigger or smaller.
- **Detail by distance:**
  - Models get simpler versions further away (**Generate LODs** in the Import
    tab, on by default).
  - Animations move every frame within 25 m, every 3rd frame up to 60 m, and
    every 8th further away or off screen.

### The mannequin
`characters/mannequin/make_mannequin.gd` builds the mannequin: its skeleton,
body and animations. To change it, edit the script and run it from the project
folder:

```
godot --headless --path . -s res://characters/mannequin/make_mannequin.gd
```

### Tuning
- `characters/humanoid_body.gd`:
  - animation distances (**NEAR_DISTANCE**, **MID_DISTANCE**);
  - ragdoll limbs and joints (**RAGDOLL**);
  - how many fall at once (**MAX_RAGDOLLS**);
  - blood marks per body (**MAX_WOUNDS**).
- `characters/zombie/zombie.gd`:
  - **SIZE_RANGE** (random sizes);
  - **CLIMB_TIME** (window climbing);
  - the walking and running paces.
- `effects/blood.gd`:
  - how much splatter stays on the map (**MAX_SPLATS**);
  - how far it's drawn.
- `world/zombie_population.gd`: **BODY_CLEANUP_DISTANCE**. Bodies are cleared
  away once you're this far and not looking.

## People

Survivors, guards, traders, the police chief, the woodworker and bandits.
A person's model is built and imported exactly like a zombie's (see **What a
character model needs** and **Getting it in** above; put people's models in
`characters/npcs/models/`).

### Whose model is whose
Every person has a **Model** setting (Inspector, **Look** group). The most
specific one wins:
1. **One person:** a survivor's file (`characters/npcs/survivors/`) has its
   own **Model**. People with their own scene (the police chief, the
   woodworker, the shopkeeper, the wagon trader) set it in their scene.
2. **A kind:** `guard.tscn`, `bandit.tscn`, `survivor.tscn`...
3. **Everyone:** `characters/npcs/human_npc.tscn`. Set it here for one
   default model for everybody. Left empty: the mannequin.

A survivor posted on a guard post keeps their own model.

### Animations
Played by name. A model's own come first; for any it doesn't have, it borrows
the mannequin's people animations (`characters/mannequin/people_animations.tres`,
not the zombie ones).

| Name | When | Notes |
|---|---|---|
| `idle` | standing around | loops |
| `walk` | walking | loops; one cycle (two steps) covers 1.4 m, sped up or slowed to match |
| `run` | running (over 3.2 m/s) | loops; one cycle covers 2.8 m |
| `talk` | while you're talking to them | loops |
| `hit_head`, `hit_body`, `hit_legs` | flinching from a hit there | plays once (about 0.4 s) |
| `rifle_idle` | guards and bandits, nothing to shoot | loops; the rifle held low |
| `rifle_walk` | bandits walking about | loops; 1.4 m per cycle |
| `rifle_aim` | aiming | loops; aim level ahead (the game tips the spine up or down at the target) |
| `rifle_shoot` | each shot | plays once (about 0.4 s) |
| `rifle_reload` | reloading | plays once, fitted to the reload time |
| `work_dig` | a survivor working a garden plot | loops |
| `work_bench` | a survivor working an ammo, shell or rifle bench | loops |

### The rifle
Guards and bandits carry the rifle's held model (`items/data/rifle.tres`, the
same one you hold) in the **RightHand** bone. Its **MuzzleFlash** is where
their shots come from. If it sits wrong in your model's hand, select the
guard or bandit scene's root and change **Rifle > Rifle Hold** (where the rifle
sits in the hand bone's space).

### Hats and other extras
Anything else under a person's **Visual** node (the chief's hat, the bandits'
bandanas) is moved onto the nearest bone when they appear, so it moves with
the head. Put it where it belongs on the mannequin (or your model) standing in
its T-pose.

### What happens on its own
- **Colors:** the mannequin's shirt and pants take the person's **Outfit
  Color** (the pants a bit darker), its skin their **Skin Color**. A real model
  keeps its own textures.
- **Ragdoll and blood:** like zombies. Shot people bleed where they're hit,
  flinch, and fall limp when they die. The rifle falls with the hand.
- **Detail by distance:** the same as zombies.

### Tuning
- `characters/npcs/human_npc.gd`: **WALK_PACE**, **RUN_PACE**, **RUN_FROM**.
- The mannequin's people animations are made by the same script as the
  zombies' (`characters/mannequin/make_mannequin.gd`, the **People** part).

## Free models

Free models must be **CC0** (no credit needed) or licensed for games. Note each
one's source and licence in a `LICENSES.txt` next to it (make the file with the
first one). Good places to look:
- Poly Haven
- OpenGameArt (filter by CC0)
- itch.io (search "CC0 3D")
- Quaternius and Kenney (low-poly)
- Mixamo (free with an Adobe account): rigged characters and hundreds of
  animations. Check its terms for your use.
