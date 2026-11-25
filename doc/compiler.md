# The compiler, as seen from the port

Findings about `ia-atmos/lang` while porting SNKRX, with what the
port does about each one. Each entry says the commit of the compiler
where it was seen, and its status.

| | Finding | Status |
|-|---------|--------|
| 1 | Time is global | by design; a clock per pool is a question for the author |
| 2 | A table cannot keep the tasks of a pool | a flat table pinned in the block of the pool can; a nested one cannot (a question for the author) |
| 3 | `math` has no `atan2`, `exp`, `log` | fixed in `9ec67ec` |
| 4 | `pub` accepted as a name | fixed in `9ec67ec`: a compile error |
| 5 | A hang when the program ends inside an emit | fixed in `9ec67ec` |
| 6 | `await :all` on an empty pool | fixed: satisfied at once; the guard is gone |
| 7 | A spawn in a loop or an `if` ends with its block, silently | caught at `3cc4855`: a compile error when the spawn ends its block; it found 3 more in the port |
| 8 | A time await splits the time of the tick for every task | by design of the runtime, as far as the port knows; the port integrates on `:clock`, so a tick can take two steps (a question for the author) |
| 9 | The new rules of `pin` | migrated at `3a6ffe9`, tests identical; three strange cases and one workaround (shared springs) left |

The port followed `main` of the compiler; it was at `995c3b2` when the
three fixes arrived. It is now pinned at `44dbe47` (`tools/setup.sh`),
which has the check of finding 7: `main` has since changed the rules of
`pin` (`98ad03a`), and moving to them waits for the author.

## 1. Time is global: no clock for a part of the program

Seen at `2f45211`.

The original slows the game down with a factor per group of objects:
the arena updates its main group with `dt*slow_amount*main_slow_amount`
and its other groups with `dt*slow_amount`, while the global timer and
the buttons of the pause menu run in real time (`arena.lua:409-417`).
When the snake dies, the main group slows to a stop in 0.7 s while the
interface keeps moving.

In Atmos, time is an emit of a number, and it must be global:

```
pin ts = tasks()
spawn @ts T()
emit @ts (50000)    ;; ==> invalid emit : expected global
```

So a pool cannot have its own clock, and `await 100ms` in a task of
the pool always follows the time of the whole program.

What the port does: the engine scales the time it emits by a global
factor (`eng.slow`), and emits the real time of each tick as an event
`:tick [us]`, for what must keep moving. Tasks of the interface that
must ignore the slow motion count real ticks instead of awaiting a
duration.

What would help: time emitted to a task or a pool, which advances the
timers of that subtree only, e.g. `emit @ts (us)` for a pool that is
toggled off for the global time.

Status: time is global by design. Whether a pool or a task may have a
clock of its own is a question of the language, raised to its author.

The answer of the session `atmos-lang` (the compiler; read from
`rt/task.c`, 2026-11-16):
each timer keeps its own time left, and time is an ordinary event; only
the bookkeeping of the pieces of a tick (`CLK_MIN`, `CLK_LATE`) is
global. The refusal is a check at run time, in `a_emit`, not at compile
time; the reference in Lua has the same check (`atmos/run.lua`). To
allow `emit @t (d)` and `@ts (d)` would cost about 40 lines in the
runtime, but two tasks could then disagree on the time (`late` and
`atm_step` would need a rule): item 33 of the list of the compiler, not
decided. A game frozen while a menu runs needs no clock of its own:
`toggle` does it (a subtree toggled off gets no events, time included);
a clock per subtree is needed only for another speed, as slow motion.

In the port: the shop under its tutorial and the win under its credits
are frozen that way (`toggle on ... with :draw`). The options could
replace `eng.slow(0)` by a `toggle` only in part: they slow the game to
a stop in 0.25 s and back (`PauseTime`, as the tweens of `slow_amount`
in `open_options` and `close_options`), and that ramp is another speed,
which a toggle cannot give. Not changed.

## 2. A table cannot keep the tasks of a pool

Seen at `2f45211`.

The physics reports contacts between bodies, and the port wants to send
each contact to the two tasks of the bodies, as the original calls
`on_collision_enter` on the two objects. For that, the world needs a
table from body to task. But a task spawned in a pool cannot be stored
in any table outside of itself, even one pinned in the block of the
pool, before or after it:

```
task T () { await(false) }
do {
    pin ts = tasks()
    pin w = [ ts=[] ]
    val t = spawn @ts T()
    set w.ts@0 = t          ;; ==> invalid escape : pinned value
}
```

What the port does: the task that steps the world emits each contact
to itself and its subtree, with the body that it is for, and the task
of each body awaits only its own (`until it.b == b`). A contact costs
an emit through the whole arena, matched by every task that awaits a
contact, instead of two emits.

What would help: a table pinned in the block of a pool, or a weak
reference to a task, that may keep the tasks of the pool and loses them
when they end.

Status: a table pinned in the block of the pool does keep its tasks
(`pin m = []`, then `set m@0 = t`). In the example, only `w` is pinned,
and the table inside it (`w.ts`) is a plain one, which could be read
out and kept elsewhere. Whether the tables built inside a `pin` should
be pinned with it is a question raised to the author.

## 3. `math` has no `atan2`, `exp`, or `log`

Seen at `2f45211`.

The original uses `math.atan2` for every angle to a target (steering,
rotations, projectiles) and `math.exp` in an easing. The `math` of this
compiler has neither, nor `log` or `tan`.

What the port did: `cmath` in `eng/eng.atm`, four functions over C.

Status: fixed in `9ec67ec`: `math` has `tan`, `asin`, `acos`, `atan`,
`atan2`, `exp`, and `log` (and `atan(y, x)` takes its second argument
since `995c3b2`). The port uses them, and `cmath` is gone.

## 4. A parameter named `pub` is the `pub` of the task, silently

Seen at `2f45211`.

```
func body (w, pub, x, y) {
    set pub.b = 1       ;; ==> invalid index : expected table : got nil
}
body(w, [], 0, 0)
```

`pub` is a keyword, but it is accepted as the name of a parameter (and
of a `val`), which then refers to the `pub` of the running task, not to
the argument. The error comes later, far from the cause.

What the port does: no variable is named `pub`.

What would help: a compile error for `pub` as a name.

Status: fixed in `9ec67ec`: `invalid declaration : unexpected 'pub'`.

## 5. The program hangs when it ends inside an emit from an awaited task

Seen at `2f45211`.

```
task Item () { await(false) }
task Inner (ui) {
    spawn @ui Item()
    await 1s
    emit @:global :done
    await(false)
}
task Outer () {
    pin ui = tasks()
    await Inner(ui)
}
spawn Outer()
await :done
print("main ends")
```

The main chunk awakes on `:done` and ends, which aborts `Outer` while
`Inner`, awaited by `Outer`, is still inside its `emit`. The abort never
returns: the program spins in `a_blk_xfer` (`rt/task.c:1958`), with no
output, and does not react to SIGTERM. Without the `spawn @ui` in
`Inner`, or with `spawn Inner(ui)` instead of `await Inner(ui)`, or with
an `await 1s` after the `print`, it ends normally.

The port met it in a test whose main chunk ended on the event that ends
a level (`tst/game/level.atm`). The game itself does not end that way.

What the port did: the test awaited a moment before it ended. Later, a
test of a level hung again in this way, and was left spinning by the run
of the tests (which now kills a test after 600 s).

Status: fixed in `9ec67ec`. A block that aborted its tasks waited for
the ones it pinned, but not for the ones confined to it that nobody
pinned: `Inner`, inside its emit, could only unwind when the control
returned to it. The block now waits for those too. The example is the
test `tst/cases/late-10.atm` of the compiler, and the tests of the port
no longer wait at their end.

## 6. `await :all` on an empty pool never awakes

Seen at `2f45211`.

```
pin ts = tasks()
await :all ts           ;; never awakes
```

`await :all ts` awaits the pool to drain, including tasks spawned into
it while it awaits, but on a pool that is already empty it awaits the
next one forever. The port guards it: `if #ts > 0 { await :all ts }`.

Status: fixed in the compiler (manual, "Await", at `c4e99c4`): an
`await :all` over an empty pool is satisfied at once (the reference
still waits). The port dropped its guard (`Quiet`, `src/level.atm`),
with the same outputs.

## 7. A task spawned in a loop or an `if` ends with its block, silently

Seen at `995c3b2`.

```
task T (n) {
    defer { print("T", n, "aborted") }
    await :go
    print("T", n, "got go")
}
loop i in 2 {
    spawn T(i)          ;; aborted at the end of each iteration
}
if true {
    spawn T(2)          ;; aborted at the end of the if
}
emit @:global :go       ;; nobody gets it
```

A task spawned with no pool belongs to the block where it is spawned,
and the body of a loop, of an `if`, or of a branch of `ifs` or `match`
is a block. So a spawn there is aborted when the block ends, at once if
the task awaits anything. This is the rule of structured lifetimes, and
the manual shows it with a `do` block (the tasks spawned in it are
aborted at its end); but nothing points at it in the code, and the
mistake is easy, since in the original the timers that the port replaces
belong to the object, wherever the code that starts them is.

The port had it in 29 places for a while: the units never attacked
(`spawn Character(...)` in an `if`, and `spawn Shoot(...)` in a loop),
the flashes of the hits never showed, and the elites never attacked.
The tests did not catch it, since the traces only showed hits and
deaths. It was found when a test of the crits of the rogues printed
none.

What the port does: each such task goes to a pool of its owner
(`spawn @fxs HfxUse(...)`), or is awaited in a `spawn { ... }` at the top
of the task. A small script lists the spawns with no pool in a nested
block (the only one left is meant: a screen pinned in `main.atm`).

What would help: a warning for a spawn with no pool as the last
statement of a block, or in a block that ends without awaiting it.

### Caught by the compiler, at `3cc4855`

The compiler now refuses a spawn with no pool, whose value is unused,
that is the last statement of its block, of a task that may await:

```
invalid spawn : the task is aborted at the end of its block
```

It found three more in the port, each a `spawn { ... }` inside an `if`.
The script above missed them: it skipped the anonymous spawns
(`spawn {`), since the body of one is a task of its own, and it looked
at the block inside the spawn, not at the block around it.

- `src/shared.atm`, `Transition`: the gold of a level never counted up
  in the transition to the shop (`if e.counting { spawn { ... } }`); it
  showed the zeros of the first text until the end. Fixed by the test
  inside the spawn; `tst/game/gold` shows the three steps.
- `src/fx.atm`, `HitCircle`: the circles of the hits never changed to
  the color of the unit or enemy halfway (`if o.change_color { spawn
  { ... } }`), as `HitCircle:change_color` does. Fixed the same way;
  `tst/game/hitcircle`. The fix moved positions and deaths in six
  arena tests, though a color is never read by the game: see 8.
- `src/snake.atm`, the bounce on a wall: the followers never flashed
  nor sounded in turn after the leader (`if i > 0 { spawn { await ...;
  spawn HfxUse(...) ... } }` in a loop), as the `trigger:after` of
  `Player:on_collision_enter`. Under it, a second defect the compiler
  cannot see: the inner `spawn HfxUse` is not the last statement, but
  its block ends right after the two sounds, so the flash would have
  been aborted too. Both go now to the pool of the arena (`WallHit`),
  as the global `trigger` of the original, so they outlive the bounce.
  Eleven arena tests moved: the new waits split the time (see 8).

## 8. A time await splits the time of the tick for every task

Seen at `9ad3291` (and at `44dbe47`).

```
spawn {
    loop us on :clock {
        print("clock", eng.tick(), us)
    }
}
spawn {
    await 25ms
    print("woke", eng.tick())
}
```

prints

```
clock	1	16666
clock	2	8334
woke	2
clock	2	8333
clock	3	16667
```

The runtime wakes a time await at its deadline, so it cuts the time of
the tick there, and every task that awaits the time gets two events in
that tick. This is exact for the timers. But the port steps its physics
on `:clock` (`src/arena.atm`, `phys_step(w, us/1000000)`), and its
springs, tweens and movements integrate on it, some once per event
(`loop on :clock`, with no `us`). So any timer, anywhere, gives the
whole game two steps in that tick, and a change that only adds a timer
moves the game: the fix of `HitCircle` above (a wait of 0.15 s for a
color) moved the positions and deaths of six tests.

The original steps once per frame, with the `dt` of the frame.

What the port could do: step and integrate on one event per tick of
game time, emitted by the engine (not on the events of the runtime's
time), and keep `await 1s` for the timers. This changes the expected
outputs of every arena test, so it is left for the author to decide.

### A longer trace of the original (2026-11-21)

The branch `step` does it (`7c825f8`). To tell which of `main` and
`step` is closer to the original, the original was traced longer:
`tst/original/run2.sh`, the run of `run1` to 9000 ticks, with GO in the
shop of level 2 and the events of the game (`SNKRX_TRACE_GAME` of
`tools/bench/bench.lua`: the deaths of the seekers, the hits of the
units, the waves). With its seed, the original buys a sentry, so the
port ran each level with one sentry (the same scene, no input), on
`main` (`d031f2b`) and on `step`, with five seeds each (the port's
random numbers are not the original's, so one run of the port is one
sample). The ticks are from the start of the arena:

| measure | original | `main`: median (range) | `step`: median (range) |
|---------|---------:|-----------------------:|-----------------------:|
| level 1, second wave starts | 1693 | 1213 (994 to 1463) | 1464 (1190 to 1764) |
| level 1, cleared | 2450 | 2208 (1666 to 2707) | 2441 (1427 to 3073) |
| level 1, seekers of the first wave | 8 | 7 (6 to 8) | 8 (7 to 8) |
| level 1, hits on the sentry | 13 | 18 (12 to 21) | 18 (16 to 23) |
| level 2, second wave starts | 1400 | 1412 (1203 to 2011) | 1710 (1464 to 2057) |
| level 2, the sentry dies | 2945 | 1921 (1671 to 2513) | 2221 (1903 to 2447) |

The median of `step` is the closer on four measures, the same on one,
and farther on one (the second wave of level 2). In level 1, the second
wave of the original (1693) is out of the range of `main` and in that
of `step`. A spawn that finds a seeker over its point is skipped in the
original too (`run2`: one of the 8 of the second wave of level 1, at
tick 2401, and three in level 2), so the seeker that `step` lost in the
first trace is the original's rule, not a defect of `step`. The original
is one sample, and the ranges overlap.

In level 2, the sentry dies earlier in the port than in the original,
on both branches and in all ten runs (1671 to 2513 against 2945): a
difference of its own, out of the reach of the step (TODO #26).

### Merged, on env-sdl (2026-11-22)

By the author's decision, the step is on `main` since the branch `step2`
(`6ba11e3`), made again on env-sdl, which declined to emit a step of its
own: the engine sums the pieces of the clock of a frame (`loop us on
:clock` in `eng/eng.atm`) and emits their sum once, `:step [us]`, in the
first pass of env-sdl (`:advance`, after the time and before `:draw`),
so the step carries exactly the game time of the frame, even when a timer
changes the factor of the clock in the middle of it. The 44 uses of
`:clock` of the game (and those of 5 tests) step on it; `await d` stays
on the clock.

The long scenes (`tools/bench/long.atm`, one sentry, five seeds) give the
same numbers as above on env-sdl: `main` before the merge as the column
`main`, and `step2` as the column `step`, measure for measure. 20 tests
changed their expected outputs. `chars2` no longer shows a barrage of
the cannoneer (one shot per 6 s, and a chance per shot), but the path
(the class chance of a barrage) stays shown by the archer in `classes`.
The logic of the stress (`SNX_PROFILE=1`, no window, three runs each,
alternated) took 3.107 s against 2.976 s before (3.229, 3.034, 3.107
against 3.170, 2.976, 2.935).

### Why the sentry dies sooner in level 2 (TODO #26, 2026-11-22)

The rules match the original, checked one by one: the turrets of the
sentry (one every 7 s, 15 s, four arrows every 2.75 to 3.5 s, a turn of
pi per second), the seekers of level 2 (hp 20.8, damage 7, 5.7 per hit
on the sentry after its defense, three contacts kill one), the push of a
contact (25 to 35, and a pushed seeker faster than 60 hits the others
for a quarter and a half of the push), the elites (6% per seeker), the
filters of the world, the steering, the damping (0.9753 per tick in
both, `1/(1 + 1.5/60)`). The opt-in traces of the original
(`SNKRX_TRACE_HITS` of `tools/bench/bench.lua`) give the hits on the
seekers by source; in level 2, until the sentry dies:

| | original | port (5 seeds) |
|-|---------:|---------------:|
| seekers alive, mean | 2.88 | 2.65 to 4.05 |
| contacts per 1000 ticks of a seeker | 2.12 | 1.82 to 3.56 |
| hits of the arrows of the turrets per 1000 ticks | 4.75 | 1.58 to 4.09 |
| hits between seekers, per contact of the sentry | 1.53 | 0.67 to 1.33 |
| ticks of a push of force 25 or more, mean | 106 | 55 to 76 |

So the seekers die more slowly in the port, mostly because a pushed
seeker stops sooner and hits fewer others. One cause found: the
friction. The original never sets one, so its fixtures have the default
of LÖVE 11, 0.2 (measured: `Fixture:getFriction()`); the port had the
0.6 of Box2D 3, and a pushed seeker that grazed a wall lost most of its
speed (284 to 33 px/s in two ticks). With 0.2 (`c17ce1e`, test
`eng/friction`), a push lasts 63 to 78 ticks (seeds 1 to 3), still short
of the 106 of the original. On the long scenes (five seeds each, main
before and after):

| measure | original | before | friction 0.2 |
|---------|---------:|-------:|-------------:|
| level 1, second wave starts | 1693 | 1464 (1190 to 1764) | 1456 (1032 to 2223) |
| level 1, cleared | 2450 | 2441 (1427 to 3073) | 2905 (2687 to 3481) |
| level 1, seekers of the first wave | 8 | 8 (7 to 8) | 8 (7 to 8) |
| level 1, hits on the sentry | 13 | 18 (16 to 23) | 18 (17 to 20) |
| level 2, second wave starts | 1400 | 1710 (1464 to 2057) | 1970 (1435 to 2221) |
| level 2, the sentry dies | 2945 | 2221 (1903 to 2447) | 2162 (1848 to 2756) |

The fix does not bring the scenes nearer to the original (the one run
of the original against five seeds, ranges that overlap): the sentry
still dies sooner, and the rest of the gap is open. Left to look at:
the solver of Box2D 3, which applies the restitution after the friction
(the bounce of `eng/friction` keeps 160 of the 200 along the wall,
LÖVE 140), and why the arrows of the turrets hit fewer seekers per
arrow (10% against 16%).

Further, measured (2026-11-23):

- **The arrows are not the cause.** In level 2 until the sentry dies,
  the original fires 88 arrows, 14 hit (15.9%) and 70 end on a wall.
  The port with seed 3 fires 88 too and hits 13 (14.8%), and its sentry
  dies at 2756; the seeds whose sentry dies early hit 4% to 9%. The
  rate follows how long the sentry lives. The seekers near the sentries
  match (sampled every 30 ticks: within 64 px 0.78 in the original,
  0.44 to 0.89 in the port; within 128 px 1.75, 1.21 to 2.16;
  `SNKRX_TRACE_NEAR` of the bench). The rules of the sentry and of its
  arrows match the original (`Sentry`, `player.lua:3099-3170`).
- **The spin of a push was three times too fast** (`9f11a0d`, test
  `eng/spin`). LÖVE divides an angular impulse (and a torque) by
  meter^2; the port gave it to Box2D unscaled, and a pushed seeker spun
  at the limit of Box2D 3, a quarter turn per step (47 rad/s), against
  15.85 rad/s in LÖVE for 8pi. A spinning seeker lost its bounce on a
  wall by its corners (in one push, 284 to 32 px/s in two ticks). An
  isolated push, with no wall, lasts 109 ticks in LÖVE and 108 in the
  port; against a wall over 400 angles and spins, 79.1 ticks in LÖVE
  and 77.9 in the port after the fix. Nine arena tests changed (`arena2`
  now runs 1500 frames so that its unit dies, and the second shot of
  `bosses` moved to tick 500, before the snake dies).

The long scenes after the fix (five seeds, median and range):

| measure | original | friction 0.2 | the spin fixed |
|---------|---------:|-------------:|---------------:|
| level 1, second wave starts | 1693 | 1456 | 1476 (966 to 1645) |
| level 1, cleared | 2450 | 2905 | 2470 (1842 to 2729) |
| level 1, seekers of the first wave | 8 | 8 | 8 (7 to 8) |
| level 1, hits on the sentry | 13 | 18 | 17 (16 to 20) |
| level 2, second wave starts | 1400 | 1970 | 1593 (1436 to 1833; seed 4 died before it) |
| level 2, the sentry dies | 2945 | 2162 | 1657 (1509 to 2170) |

Level 1 and the second wave of level 2 came near the original; the
sentry of level 2 dies sooner still. In the game, a push of force 25 or
more still lasts 62 to 93 ticks (means of seeds 1 to 3, against 106),
with a top speed of 376 to 434 px/s against 331: almost every push of
the port reaches a wall.

- **The time of the begin of a contact** (`#26`). LÖVE (Box2D 2.3)
  calls it inside the step, before the solver, so a push from a contact
  starts from the velocity of before the contact; Box2D 3 reports it
  after the step, when the solver has already bounced the seeker off
  the unit, and the push adds to the bounce. The engine now keeps the
  velocity of each body before the step (`body_vel0`), and the four
  pushes from contacts (a unit, a force field, a seeker thrown into
  another, an elite's charge) start from it. Six arena tests changed
  in their ticks (`arena2`, `arena3`, `bosses`, `classes`, `elites`,
  `run`); each still shows what it exists to show.

The long scenes with fifteen seeds (1 to 15), before and after, median
and range:

| measure | original | before | contact before the solver |
|---------|---------:|-------:|--------------------------:|
| level 1, second wave starts | 1693 | 1222 (755 to 1645) | 1279 (754 to 2012) |
| level 1, cleared | 2450 | 2470 (1605 to 3194) | 2459 (1880 to 3020) |
| level 1, hits on the sentry | 13 | 18 (14 to 20) | 17 (14 to 21) |
| level 2, second wave starts | 1400 | 1472 (999 to 1990) | 1666 (1025 to 2484) |
| level 2, the sentry dies | 2945 | 1897 (1509 to 2668) | 2014 (1669 to 3203) |

Four of the five measures moved toward the original, one away; the
ranges are wide, and the original is one run, so the gain is small and
uncertain. The change is kept since it is the order of the original's
engine. The sentry of level 2 still dies sooner than in the original.

## 9. The new rules of `pin`

Seen at `3a6ffe9` (the rules since `98ad03a`). The port moved to them
from `44dbe47`, with the guide of the session `atmos-lang`
(`.claude/plans/261115-pin-migration.md`). The traces and screenshots
of the tests stayed identical.

Most of it was a change of keyword: a table or a function that a block
creates is declared with `pin`, and a `val` only names a value that has
an owner. The rest was a handful of shapes, each with a rewrite.

**Built in a task, kept outside.** Many objects of the game are built
by their task and kept in a table of the arena (`A.enemies`,
`A.critters`, `A.units`, the bodies of the world, `CAM.shakes`, the
texts under the mouse). Such an object is now made in the place that
keeps it, and the task names it:

```
val c = vector.insert(A.critters, [ kind=:critter, ... ])
val o = body(A.w, [ kind=:bomb, ... ], :static, x, y, :player, [:rect, 8, 8])
set e.st = steerable(e.b, ...)      ;; and `val st = e.st`
```

`body()` now keeps the record in the world and returns it. A token
(section 12 of the study) is made in its field the same way.

**A filtered list.** `pin es = [] ... set A.enemies = es` became
`set A.enemies = do { pin es = [] ... es }`.

**A variable that takes a new table.** `var cs = []` with `set cs = []`
became `pin cs = []` and `vector.clear(cs)`, or a field of a pinned
table (`pin g = [ run=..., screen=... ]` in `main.atm`).

**An event kept after the await.** `set p = await :Push` (the push of a
critter or an elite) became a copy of its fields: an event has no
owner, and a variable cannot own it.

**A value of a task, emitted to its owner.** A button sent its spring
in its click (`[id, spring=s]`), and the owner pulled it. A value of
the button cannot go out to its owner, and the item cards are in a
pool inside a `do` of the shop, deeper than the shop. The springs that
go in events are now owned by the program (`SHARED_SPRINGS`, removed in
a `defer` when the widget ends).

**Objects of the arena in global events.** The hits, pushes, curses,
and heals were `emit @:global`, carrying the enemy, the unit, the area,
the projectile. A global emit only accepts values of the global block.
The tests pinned the arena at the top of the program, so they passed;
the game keeps it in the task `Play`, and the first hit of a real run
failed. These events now go to the task of the arena (`send(to, ev)`,
to `to.at`, which `body()` sets from the world).

**A task given to a task of an outer pool.** The buttons of the win and
of the death, spawned in the pool `ui` of the arena, received the task
that awaited them (`Won`, `Died`), which ends earlier. The win now
emits its choice to the program (it holds only an id); the death keeps
its button in a pool of its own (it lasts until the next screen); the
choice of a passive keeps its reroll button in a pool of its own and
ends with the transition.

**A text shared by two tasks of an outer pool.** `Text2` and `Cbyc`
received the same text, pinned in `Won` and `Died`; the text is now
`Text2`'s, which runs its own `Cbyc`.

### What is strange

A function cannot name its argument, nor a part of it, with either
keyword, when its callers pass both fresh and owned values:

```
func f (t) {
    val m = t           ;; fails when called as f([1, 2])
    pin m = t           ;; fails when called as f(owned)
    val p = t@0         ;; and the same for a part of it
}
```

Only the parameter itself, or a copy (`X.copy(t)`), works for both.
The port reads the numbers it needs (`polys_overlap`) or copies
(`X.copy(mods || [])`).

A closure that captures a fresh argument pins it, and the argument can
no longer go out in an event. The line in the message is the line of
the closure, not of the argument:

```
task Area (a) {
    pin res = \(d) { a.n + d }
    emit @:global :Hit [ area=a ]   ;; invalid escape : table pinned at <the closure>
}
```

Without the closure, the emit passes. The port captures a number
instead.

`text(lines)` kept the lines of its caller; a message that comes in an
event then made its text unable to go into the list of open texts. The
text now copies its lines.

The registry of springs is a workaround that the rules impose for a
plain need: a child that hands a small mutable value to its owner.

A task cannot go into a fresh table that is then given to the world,
but it can go into the same table once the world owns it:

```
set rec.at = w.at           ;; invalid escape : pinned task (rec fresh)
set w.objs@(b) = rec
set w.objs@(b).at = w.at    ;; passes
```

### Removed workarounds

None. Finding 2's broadcast of contacts was the candidate: a nested
table of a pinned table now keeps the tasks of a pool, as its status
hoped. But in the port the world belongs to `A`, which is outside the
task `Arena`, and the tasks of the bodies are in pools of `Arena`; the
world cannot keep them (`invalid escape : pinned task`, measured with
the delivery of each contact to the task of its body). A table in the
block of the pools could keep them, but every `body()` and the step of
the world would need it, not `A`. The broadcast stays. The port had no
`keep(spawn ...)`, tables of context, or task accepting its own
connection.

### The cost

The commit `5c489ea`: 617 lines changed, of which 433 only from `val`
or `var` to `pin` (the compiler found most of them at compile time, the
rest at run time on the paths that the tests run). About 60 places
needed a rewrite: about 26 objects made in the place that keeps them,
7 lists given by a `do`, 4 variables cleared or kept as fields, 2
events copied, 3 widgets with shared springs, 14 emits sent to the task
of the arena (and the gold of the transition copied), 3 buttons given
pools that hold their owners, 2 texts owned by their `Text2`, the lines
of a text copied, 2 arguments read without a name, and 1 closure that
captures a number. The 40 tests gave the same traces and screenshots.

## 10. The stable rules of `pin`

Seen at `c4e99c4` (the rules declared stable on 2026-11-19, at
`8361f88`). The port moved to them from `3a6ffe9`, the last migration
of these lines. The 40 tests gave the same traces and screenshots.

The compiler found every site at compile time: 35 warnings `pinned
value given away by its block (expected 'val')` in the sources and one
in a test (`tst/game/drag.atm`), each a function that builds a table in
a `pin` and returns it. The warning points at the line that gives the
value away (the return), not at the declaration. Each became `val`.
Two more sites failed at run time on paths the warnings do not see:

```
func body (w, rec, type, x, y, tag, shape) {
    ...
    :polygon => do {
        pin pts = shape@1       ;; invalid pin : table named at <the line of body>
```

The parameter `shape` names a fresh table, so it may not be adopted one
block deeper; `val pts` reads it. And in `text_parse`, a pinned state
(`pin st = [ tags=[] ]`) gave its `tags` to the characters it returned
(`invalid escape : table pinned at ...`); the tags became a `var`.
`X.xin` is now `X.in` (28 lines).

Removed workaround: an argument that callers pass fresh or owned can be
named again (`val m = mods || []` in `Attack`, where the first
migration copied it with `X.copy`). The lists given by a `do`
(`set A.enemies = do { pin es = [] ... es }`) still work and were left
as they are.

The cost: 22 files, 71 lines changed; 36 `pin` to `val`, one to `var`,
one `pin` to `val` for an argument, the `X.copy` gone, and the rename.

The time of the logic in the stress scenario (1500 ticks, 200 more
seekers, `SNX_PROFILE=1`, no window), five runs of each, alternated:
3.60 s at `3a6ffe9` and 4.04 s at `c4e99c4` (medians), about 12% more.
Whether it comes from the runtime (the marks of finalized data, the
checks of the emits) or from the port's changes was not separated.

### The time of the logic, by compiler (`atmos-pin#14`)

The same tree (`a770cd3`, after the migration), the stress scenario
(1500 ticks, 200 more seekers, `SNX_PROFILE=1`, no window, `-O2`), each
compiler built in its own worktree, the runs alternated across the
compilers (seven of each), nothing else running:

| `ia-atmos/lang` | builds | runs | 40 tests | logic (s, median) | ticks/s |
|-----------------|--------|------|----------|------------------:|--------:|
| `138f392` | yes | no: `invalid escape : task pinned at src/menu.atm:32` | | | |
| `7480111` | yes | no: the same | | | |
| `8c9453c` | yes | yes | 40 identical | 3.90 | 333 |
| `8361f88` | yes | yes | 40 identical | 4.07 | 319 |
| `c4e99c4` (setup) | yes | yes | 40 identical | 3.72 | 347 |
| `f06fd26` (branch `pin`) | yes | yes | 40 identical | 3.94 | 327 |

The ticks per second are 1500 over the median time on the clock of the
run. Between these four compilers, the differences are within the
spread of the runs (3.65 to 4.92 s). The tree before the migration
(`ae9c69f`) runs only on its compiler `3a6ffe9`, and neither old
compiler runs either tree, so runs alone cannot split the cost between
the compiler and the port. Alternated with `c4e99c4` (seven of each):
3.31 s for the old tree on `3a6ffe9`, 3.97 s for the new one on
`c4e99c4`.

`callgrind`, 700 ticks of the same scenario, instructions:

| | total | `a_unname_x` | `a_clr_tmp` | `a_cycles` / `cyc_collect` | `a_name` |
|-|------:|------------:|-----------:|---------------------------:|---------:|
| old tree, `3a6ffe9` | 17.11 G | not called | not called | not called | not called |
| new tree, `c4e99c4` | 19.66 G | 1.71 G | not called | 0.06 G | 0.01 G |
| new tree, `f06fd26` | 20.18 G | 1.71 G | 0.76 G | 0.06 G | 0.01 G |

So most of the extra instructions (2.55 G, 15%) are `a_unname_x`, and
1.28 G of it comes from one function, `separate` (`eng/steer.atm`, the
loop over all the other enemies of each seeker, 17% of the program):
4.9 million times in 700 ticks, about 260 instructions each. It is not
a walk of the records: at the end of each step of `loop _, o in
others`, the generated C un-names every slot of the body, its names
and its temporaries (23 in a standalone copy of `separate`), and
`ceil_up` returns at once for each, since most hold numbers. The same
standalone program, with no physics or window, shows the same share
(9% of its instructions in `a_unname_x`, about 155 per step), whether
the records come as arguments of a spawn or are made in their vector.
The branch `pin` adds `a_clr_tmp` (0.76 G). The rest of the top of the
profile (`emit_trail`, `probe`, `a_tab_get`, `a_call`) is the same in
the three.

The fix of `atmos-pin` on the branch `pin` (`23a063e`: the end of a
block tests its slots inline, before any call): 3.79 s against 3.96 s
for `c4e99c4` (medians of five, alternated, the same tree), and the 40
tests identical. The port stays on `c4e99c4` until it is on `main`.

### On the branch `contacts`: the contacts sent to their two tasks

With `set :out` (since `8361f88`), the task of each body writes
`set :out A.w.objs@(b).task = task` after its `body(...)`, in its own
block; the place goes back to `nil` when the task ends. `phys_step`
emits each contact with `emit @(o.task)` to the task of its body only,
instead of to the whole arena. The world stays in `A`, made by the
caller of the arena. 18 tasks register; the walls do not (no task
awaits their contacts). The 21 awaits keep their `until it.b == ...`:
an emit to a task also reaches its subtree, which may hold the tasks of
other bodies. The 40 tests are identical.

In the stress scenario, the logic takes 3.27 s against 4.04 s on `main`
(medians of seven, alternated, `SNX_PROFILE=1`, no window), and the
whole run (`tools/bench/perf.py`, with the window, three runs) 12.61 s
against 13.33 s on the clock, 119 against 113 ticks per second.

At first `SHARED_SPRINGS` stayed: a widget lends its spring to its owner in an
event, and the form of `set :out` would need a table from each owner
through some 30 places that spawn widgets, and one of the widgets
(`ItemCard`) has an owner only in the shop. A `set :out` in an `if`
is cleared at the end of the `if`, so it cannot be conditional:

```
task Child (o, id) {
    pin s = [ k=10 ]
    if o {
        set :out o.springs@(id) = s     ;; nil again at the end of the if
    }
    ...
}
```

Since `a80a77f` (`atmos-pin#16b`, approved), the place of a `set :out`
lasts until the value ends, wherever the `set :out` is written, so the
form above is right: the widgets lend their springs to their owners
with a conditional `set :out`, and `SHARED_SPRINGS` is gone (the branch
`contacts-pinout`, merged into `main` with #2; the 40 tests identical).

The rules of 2026-11-21 (`atmos-pin#17`, the ceiling on the value only;
`atmos-pin#18`, no collection of unpinned cycles), at `ia-atmos/lang`
`95b0d0b` against `7db3c99`, the tree of `main` at `90b0d95` (on
env-sdl): the logic of the stress (`SNX_PROFILE=1`, no window, no
sound, `-O2`, three runs alternated) takes 2.985 s against 2.937 s
(2.985, 3.076, 2.927 against 3.037, 2.937, 2.767), within the spread of
the runs; the 40 tests are identical, and with `ATMOS_ASAN=1` no test
reports a leak.
