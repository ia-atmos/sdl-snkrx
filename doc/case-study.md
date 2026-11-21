# SNKRX in Atmos: the case study

The port of SNKRX (a327ex, Lua over LÖVE) to Atmos (structured
synchronous concurrency, over SDL2) asked one question: what happens to
the timers with callbacks and to the flags that guard the phases of a
game, when each behavior is a task that awaits.

This document sums up the answer. The details are in the other
documents: `study.md` (twelve behaviors side by side), `state.md` (every
flag and timestamp of the original, and what became of it), `bench.md`
(the port against the original), and `compiler.md` (the findings about
the compiler).

## What was ported

The whole game as played: the menu, the shop (cards, party, classes,
reroll, lock, level, items), the arena with its waves, elites, and
bosses, the 54 characters of the original's list with their summons, the
sets of the 16 classes, the 82 passives with their choice every third
level, gold, the win at level 25 and the loops, new game plus, the
options with the game paused, the music, and the save of the state and
of the run.

The texts that explain an object under the mouse (`InfoText`) and the
messages of the shop came later, with the build at the end of a level.

Dragging a unit in the party came with them.

The options came complete: mouse control, the run timer, the size of
the window, the cooldowns and the arrow drawn on the snake, and screen
movement.

The tutorial of the shop, the credits, and the buttons that open pages
on the web came last: the shop under its tutorial, and the win under its
credits, are toggled off (`toggle`) but for their drawing.

The 24 achievements are kept in the state, with their names in the
original (`achievement_*`), and set where the original sets them; no
screen of the original shows them, so the port shows none.

Left out: Steam (the achievements were kept for it, and its rich
presence).

## The timers

In the eight files of the game, the original calls its timer 422 times:
`after` (223), `every` (83), `every_immediate` (18), `tween` (63),
`cooldown` (32), and `during` (3); and cancels a timer by its tag 5
times. A timer with a tag replaces the running one of the same tag.

In the port, these are 370 `await`s in 27 files, with 59 `par`, 647
`spawn`, and 51 `emit` (`src/*.atm` and `main.atm`, comments left out).
They are not one for one: a sequence of timers nested in callbacks
(`after(a, function() after(b, ...) end)`) is one task with two awaits,
and a loop of timers (`every`) is a `loop` with one.

Six patterns cover the timers of the original:

| The original | The port | Study |
|--------------|----------|-------|
| `after(d, f)`, nested | `await d`, then the code of `f`, in sequence | 6, 9 |
| `every(d, f, n, after)` | `loop _ in n { await d ; f }`, then `after` | 9 |
| `cooldown(d, cond, f)` | `await Cooldown(u, d, cond)`, then `f` (a task that ends when the attack may happen) | `src/attack.atm` |
| a timer with a tag, restarted | a `par :any` between the wait and the next request | 12 |
| a timer with a tag, from many places | a token in the field, cleared only by its holder | 12 |
| a timer that undoes an effect | a task that does it, awaits, and undoes it in a `defer`; a count of such tasks when they add up | 8 |

## The flags

`state.md` lists 70 variables of the original that guard a phase or
compute a time (counting the nine flags of the steering as one, the
`selected` of the four buttons of the shop as one, and the `info_text`
of the objects under the mouse, and of the messages, as one each). In
the port, 36 of them are gone: the phase they guarded is a place in the
code of a task. The other 34 became 34 variables, and none guards a
phase of the task that sets it: 18 are fields that other tasks read (a
curse, a slow, a stun), 6 count running tasks or events, 6 are locals
of a task, and 4 are fields of the run or of the HUD.

So the flags that remain are state that one task shows to another. The
flags that a task kept for itself (`dead`, `being_pushed`,
`transitioning`, `quitting`, `choosing_passives`, `selected`,
`cant_be_picked_up`, `info_text`, `in_tutorial`, `in_credits`) are gone.

## What the port taught about Atmos

- A task spawned with no pool lives in the block where it is spawned, and
  a block of a loop or an `if` ends right away (`compiler.md`, 7). The
  first version of the port spawned the attacks of the units and the
  flashes of the hits that way, and they never ran; no trace showed it,
  since the traces only recorded hits and deaths. The rule is the core of
  structured concurrency, and it is what makes the timers safe: a task
  that ends takes its waits with it, where the original must check `dead`
  in callbacks. But the place of a spawn is its owner, and a pool is how a
  task names another owner.
- Time is global (`compiler.md`, 1): a pool cannot have its own clock, so
  the slow motion of a part of the game is a factor of the global time,
  and the interface counts the real ticks.
- The tasks of a pool cannot be kept in a nested table (`compiler.md`,
  2), so a contact of the physics is broadcast to all the tasks that
  await one, with a filter. With a crowd of 200 enemies, this and the
  separation of the enemies (the same O(n²) loop as the original) are
  most of the logic of a tick (`bench.md`).
- The compiler fixed three of the findings during the port (`math`, a
  name of `pub`, and a hang at the end of the program).

## The measures

From `bench.md`: in the same container, on OpenGL over Xvfb, with the
sound of both mixed, the port runs 1.07 to 1.22 times as many ticks per
second as the original in the menu, the shop, level 1, and level 1 with
200 more enemies, with 83% to 91% of its CPU time. Their peaks of memory
(546 MB and 946 MB) are mostly the sounds, which both decode whole at
the start, so they say nothing about the language. (An earlier
measurement, of 1.8 to 3.0 times and 131 MB, had a port that loaded no
sound: `bench.md`.) The logic alone of the port takes 0.089 ms per tick
in level 1, and 2.77 ms with the crowd of 200.

The timings of the original are kept where they were measured: in the
faithful version (the branch `exact`), the menu reaches the shop in
tick 113 in both, and the first marker of level 1 comes 269 ticks after
the arena starts in the port, 272 in the original (`study.md`, 9).

`main` relaxes a few of these exactnesses that no player can see, in
favor of more direct code: a wait or a tween of the interface ends at
its duration, not a tick past it, and the run timer adds real
microseconds instead of the floats of the original (the menu now
reaches the shop in tick 112). The list, with what each gives up and
gains, and the candidates rejected: `relaxed.md`.

The code, counted without comments or blank lines, with
`tools/count.py`, the port at `7639dd3` (all the features, after the
migrations of `pin`), the original at `6b93a64` as committed:

| | original | port | port/original |
|-|---------:|-----:|--------------:|
| game, lines | 10381 | 9455 | 91% |
| game, tokens | 134827 | 91671 | 68% |
| game without `main.lua` and `data.atm`, lines | 8422 | 7790 | 92% |
| game without `main.lua` and `data.atm`, tokens | 113682 | 77021 | 68% |
| engine, lines | 4428 | 2209 | 50% |
| engine, tokens | 40796 | 19370 | 47% |

The game of the original is its ten Lua files (`main`, `arena`,
`buy_screen`, `enemies`, `player`, `objects`, `shared`, `mainmenu`,
`media`, `conf`); the game of the port is `src/` and `main.atm`. The
engine of the original is `engine/` without `engine/external`; that of
the port is `eng/`, Atmos and C. Most of `main.lua` of the original, and
all of `src/data.atm` of the port, are the tables of the game (names,
costs, classes, and texts of the characters, passives, and items);
`main.lua` also has the start of the game and the options. The port
now has every feature of the original but Steam; the engine of the
original is a general one, so the engines do not compare part for
part. (Earlier counts in these documents were of smaller ports: 4755
lines at S7, 8647 at S9.)

The lines fall less than the tokens, for three measured reasons:

- The Lua of the original is denser: 13.0 tokens per line, against 9.7
  in the port. A timer with its callback often fits in one line of Lua
  (`self.t:after(0.5, function() self.x = 0 end)`), and becomes two or
  three in the port (`await 500ms`, then the code).
- Closing lines: 1821 lines of the port hold only `}` and the like
  (19% of its lines), against 1467 lines of only `end` in the original
  (14%).
- The control flow is a small part of either: 417 lines of the
  original call a timer, and 167 more close a callback (`end)`), 6% of
  its lines. The port has 1283 lines with `await`, `par`, `spawn`,
  `watching`, `emit`, `defer`, or `loop ... on` (14%): what the
  original does with flags and callbacks takes fewer tokens in the
  port, but each task also says where it lives (59 pools, 107
  `spawn { }`), and what it undoes when it ends. The rest, about four
  fifths of both, is formulas, tables, and drawing, which are the same
  size in any language.
