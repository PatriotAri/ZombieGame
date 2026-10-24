# Tests

Each `*_test.gd` here is a test: a script that starts the game (or part of
it), does something, and prints `ok` or `FAIL` for each thing it checks, then
`FAILS: <how many>`. They run with no window, at a fixed 60 frames per second,
so they go faster than real time and come out the same every run.

## Running them

You need the Godot 4.6 program. Point `GODOT` at it (on Windows, run this from
Git Bash):

```
GODOT=/path/to/Godot_v4.6-stable tests/run_tests.sh             # every test
GODOT=/path/to/Godot_v4.6-stable tests/run_tests.sh --quick     # all but the slow ones
GODOT=/path/to/Godot_v4.6-stable tests/run_tests.sh saves_test  # just one (or a few)
```

Run it from the `midwest-undead` folder or anywhere else: it finds the project
itself. It prints one line per test, and each failed check under its test.
Each test's whole output goes in a folder it names at the end (or `TEST_OUT`).

A test fails if a check fails, if it hits a script error, if it ends without
printing `FAILS:`, or if it runs longer than `TEST_TIMEOUT` seconds (900).

GitHub runs them too (`.github/workflows/tests.yml`): the quick ones on every
pull request, all of them on every push to main. A failed run keeps every
test's output: the run's page on GitHub, under **Artifacts**.

## Writing one

Copy a short one (`loot_test.gd`, `door_rule_test.gd`) and change it. Name it
`something_test.gd`, or the runner won't pick it up.

- **Don't depend on what's on the real map.** It changes as the map's built.
  Build what the test needs on a test map instead (`support/test_map.gd`):

  ```gdscript
  var map := TestMap.begin()
  TestMap.building(map, "Shop", Vector3(40, 0, 40))
  TestMap.spawn_point(map, "survivor", Vector3(-60, 0, -60), "Dale Hutchins")
  main = load("res://world/main.tscn").instantiate()
  main.map_scene = TestMap.finish(map)
  root.add_child(main)
  ```

- **If it saves**, call `preload("res://tests/support/test_saves.gd").use()`
  first thing: its saves go in a folder of their own, never with yours.
- **If it writes files into the game's folders**, delete them at the start,
  at the end and in `_finalize()` (see `add_content_test.gd`), so a test that's
  stopped halfway leaves nothing behind.
- **Count time in frames**, not the clock: 60 frames is one second of game time.
- Freeze or move away the zombies the map scatters around (most tests do it in
  their first frames), so they don't wander into what you're checking.

A test that takes more than about a minute goes in `slow.txt`, one name a
line: the quick run skips it. (The list there now is a guess from how many
frames each one runs for; the runner prints each test's time, so move them in
or out once a full run shows the real times.)
