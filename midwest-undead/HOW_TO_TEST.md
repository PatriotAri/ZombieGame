# How to test the game

Two kinds of checks run on every push and pull request (on GitHub, see
`.github/workflows/ci.yml` in the folder above this one), and you can run both
yourself:

- **Unit tests** (`tests/unit/`): small scripts that check one piece of code
  does what it should, such as an inventory giving back only what it holds.
  They use [GUT](https://gut.readthedocs.io/en/v9.6.1/) (Godot Unit Test), in
  `addons/gut/`.
- **The smoke test** (`tests/smoke/smoke.gd`): opens the main menu, then the
  game, with no window, lets it play for 10 seconds and fails if anything
  printed an error. Warnings (like a marker missing from the map) are printed
  but don't fail it.

If either fails, the change broke something: fix it before merging.

## Running the unit tests in the editor

1. Open the **GUT** panel at the bottom of the editor (next to Output).
2. Click **Run All**.

Each test shows passed or failed, with the line of the check that failed.

## Running them from a terminal

From the folder holding `midwest-undead/`, with `godot` being your Godot 4.6
executable (on Windows, its full path, e.g.
`C:\Godot\Godot_v4.6-stable_win64_console.exe`):

```
godot --headless --path midwest-undead --import
godot --headless --path midwest-undead -s res://addons/gut/gut_cmdln.gd -gexit
godot --headless --path midwest-undead --script res://tests/smoke/smoke.gd
```

The first line only matters after adding or changing files outside the
editor. Each command ends with "passed" or a list of what failed. The smoke
test ends with `SMOKE TEST: passed` or `SMOKE TEST: FAILED`.

## Writing a unit test

1. Make a script in `tests/unit/` (or a folder under it) whose name starts with
   `test_`, for example `tests/unit/test_loot_table.gd`.
2. Start it with `extends GutTest`.
3. Add a function per thing to check. Its name starts with `test_` and says what
   should happen: `test_remove_takes_only_what_there_is`.
4. In it, set things up, do the thing, then check the result:
   - `assert_eq(got, expected)`: equal;
   - `assert_true(x)` / `assert_false(x)`;
   - `assert_almost_eq(got, expected, 0.01)`: floats, give or take.

   Every check can take a message as its last argument, shown when it fails.

`tests/unit/test_inventory.gd` is a finished example to copy. The GUT
documentation lists every check and how to test nodes and scenes.

Test one thing per function, and keep tests away from randomness and the
clock: give random rolls a fixed seed so a test does the same every time.

## When the smoke test fails

The log above `SMOKE TEST: FAILED` shows each error, with the script and line
it came from. It usually means a script error while the game starts or plays,
or a scene that can't load (a broken path, a deleted file a scene still uses).
Run the game from the editor and the same error shows in the Debugger.
