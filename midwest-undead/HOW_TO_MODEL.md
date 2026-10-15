# How to add models and animations

Every weapon in your hands works with or without a model. Without one it's
today's box gun. You can swap a model in whenever you have one, and nothing else
has to change.

So far this covers **weapons in your hands** (first person). Characters, props
and buildings come later.

## The rules every model follows

- **1 unit = 1 meter.** In Blender, keep the scene's unit scale at 1.0.
- **Forward is -Z** in Godot. In Blender that's +Y forward, and the glTF exporter
  turns it for you (leave **+Y Up** ticked).
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

Weapons in your hands are only drawn one at a time and always close up, so they
get the most detail.

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

## Free models

Free models must be **CC0** (no credit needed) or licensed for games. Note each
one's source and licence in `items/models/LICENSES.txt` (make the file with the
first one). Good places to look:
- Poly Haven
- OpenGameArt (filter by CC0)
- itch.io (search "CC0 3D")
- Quaternius and Kenney (low-poly)
