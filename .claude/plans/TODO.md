# TODO

What is pending in the port of SNKRX (`261111-snkrx.md`). Items are
`#N`, unique in this session, in order, never reused; from another
session, `session#N` (this session: `sdl-snxkx`, for the repository
`ia-atmos/sdl-snkrx`). A closed item keeps its number in the index.

## Index

| # | Title | Kind | State |
|---|-------|------|-------|
| #1 | Second migration to the rules of `pin` | decision | closed: confirmed by the author (2026-11-21) |
| #2 | Contacts sent only to their two tasks, with `set :out` | decision | closed: `contacts-pinout` merged into main by the author's decision (2026-11-21), compiler `7db3c99`, 40 tests identical |
| #3 | Finding 8: step the physics once per frame | decision | closed: merged by the author's decision (2026-11-22), branch `step2` (`6ba11e3`) on env-sdl: `:step [us]` from the summed pieces of the clock, in the first pass `:advance`; 20 tests changed; the long trace unchanged by the move (`doc/compiler.md` 8); stress logic 3.107 s against 2.976 s |
| #4 | Relax exactness for expressiveness | work | done (2026-11-21): the branch `exact` (`58594e4`) marks the faithful version; R1 (real-time waits, `51c429c`), R2 (interface tweens, `f17dc27`), R3 (`tick_dt` gone, `3c9ce56`) on main; rejected candidates, among them the tweens of game time, in `doc/relaxed.md` |
| #5 | A clock per task or pool | remark | closed: answered (`doc/compiler.md`, 1); not needed by the port |
| #6 | E5: move the platform part of `eng/` to `env-sdl` | work | done: `eng/` over `env-sdl` `94cb414`, 40 tests identical but `tst/eng/input` (the new names of the events) |
| #7 | Drop the guard of `await :all` on an empty pool | work | done |
| #8 | Small differences from the original | work | done |
| #9 | The new names of the sessions in the documents | work | done |
| #10 | Why the original peaks at 946 MB | work | done |
| #11 | The S7 stress numbers are not to be compared | remark | reported, not acknowledged |
| #12 | All features in, the first `pin` migration, F5, the student's trail | remark | reported, not acknowledged |
| #13 | The time of the logic by compiler (`atmos-pin#14`) | work | done, sent to `atmos-pin` |
| #14 | Widgets lend their springs with `set :out` (`pin-out`, `atmos-pin#16`) | remark | closed: the rule became main (`a80a77f`, `atmos-pin#16b`) and `contacts-pinout` was merged with #2 |
| #15 | The counts of lines in `bench.md` and `case-study.md` (paper) | work | done |
| #16 | The CPU of the logic alone, per tick, with its method (paper) | work | done |
| #17 | How the port was written, in the README (paper) | work | done |
| #18 | The benchmark ran the port with no sound; rerun with it | work | done |
| #19 | Two latent errors of `pin` in the elites, found by the timing of #3 | work | done |
| #20 | The clear of the window by env-sdl costs 0.82 s of a stress run that the port covers anyway | remark | closed: `clear=false` (env-sdl `e0aba7b`) adopted; measured 18.42 s against 18.62 s, within the spread (`bench.md`) |
| #21 | On env-sdl the stress is 1.45 s slower on the clock; 0.63 s is not the clear and is not explained | work | closed: measured again on one compiler, builds alternated (`bench.md`, "Where the 1.45 s went"): the gap was the clear (0.70 s of it recovered by `clear=false`); 0.13 to 0.21 s remain, at the edge of the spread, in rendering and presenting |
| #22 | The frame loop on the rules of 2026-11-21 (`atmos-pin#17`, `#18`) | remark | done: lang `95b0d0b` 2.985 s against `7db3c99` 2.937 s of stress logic, within the spread; 40 identical, no ASAN leak; setup at `95b0d0b` (`4b2219f`) |
| #23 | `grab` (superseded: `grab` replaced by `mute`/`stage`/`solo`): the options take the input of the screen behind them (`atmos-lang#112a`) | experiment | branch `exp-grab` (`1167084`, lang `grab` `c66c735`), not to merge: 40 identical plus a new test; reported to `atmos-grab`; the merge of `grab` into the language is the author's |
| #24 | `context`: the stars and the background draw in their canvas by a context (`atmos-lang#112a`) | experiment | closed: adopted on main by the author's decision (2026-11-22, via `atmos-context`), one-line form `context eng.on(STARS) {...}`, lang `666dcd6`; 41 tests identical; 4.89 canvas switches per frame in the stress (24.72 before) |
| #25 | The options do not take the input today: a click behind them buys a card in the shop (the original does not update the shop while `paused`) | defect | closed (author's go, 2026-11-21): the shop opens the options itself and is toggled off behind them until they start to close (`ShopPause`, `:Shop.options`, `:Options.closing`); no flag; test `tst/game/pause`, the same output as `exp-grab`; two tutorial screenshots change (the shop frozen while paused). To be replaced by `grab` if it enters the language |
| #26 | In level 2 with one sentry, the sentry dies earlier in the port than in the original (1671 to 2513 against 2945, ten runs, `doc/compiler.md` 8) | work | open: find why (the damage per hit is the same, 18 hits in all; the seekers reach it sooner or more often) |
| #27 | `toggle` replaced by `mute` (lang `f416c03`, approved in `atmos-grab`) | work | closed: the shop and the win screen use `mute <!:draw> on :X.mute`; compiler `4b4d3c4`, 41 tests identical; `exp-grab` (#23) is superseded |

## Items

**#1 Second migration to the rules of `pin`** (declared stable by the
author). Done on the branch `pin2`, merged into `main`, by the session,
to be confirmed: the compiler at `c4e99c4` (`tools/setup.sh`), 36 `pin`
to `val` found by the compiler's warnings, two more at run time
(`eng/phys.atm` `body`, `eng/text.atm` `text_parse`), `X.xin` to `X.in`,
one workaround of the first migration gone (`X.copy` in `Attack`). The
40 tests are identical; no `invalid access : finalized` seen. The logic
of the stress takes about 12% more (3.60 s to 4.04 s, medians of 5);
`doc/compiler.md`, 10. Reported to `atmos-pin`.

**#2 Contacts sent only to their two tasks.** Update (2026-11-21):
`set :out` lasts until the value ends on `ia-atmos/lang` main since
`a80a77f` (`atmos-pin#16b`, approved); the branch `contacts-pinout`
(`contacts` plus the springs lent with a conditional `set :out`, so
`SHARED_SPRINGS` goes) passes the 40 tests identical on it. Recommended:
merge `contacts-pinout` with the compiler at `a80a77f` or later.
Earlier: done on the branch
`contacts` (`cd9689a`, `dc0e805`), not merged (asked by `atmos-pin`:
not without the author). Each task of a body writes
`set :out A.w.objs@(b).task = task`; `phys_step` emits each contact to
that task only. The 40 tests are identical. The logic of the stress
takes 3.27 s against 4.04 s (medians of seven), the whole run 119
against 113 ticks per second. The filters `until it.b == ...` stay
(an emit to a task reaches its subtree), and `SHARED_SPRINGS` stays (a
`set :out` cannot be conditional, and the owners are many); details in
`doc/compiler.md`, 2, on the branch. Reported to `atmos-pin`.
Recommended: merge.

**#3 Finding 8** Done on the branch `step` (`a76264c`, `7c825f8`), not
merged: `eng.h` emits `:step [us]` once per tick, after its time, and
the 51 uses of `:clock` step on it; 40 tests green with 19 expectations
changed (`doc/compiler.md`, 8, on the branch, has the comparison). Two
forms in Atmos were measured and differ from it (13 and 5 tests), so
the step is emitted by `eng.h`; over `env-sdl`, a first pass of drawing
before `:draw` gives the same order. On the one measure the original's
trace allows (its first wave), `main` is the closer: `step` loses one
seeker of the first wave to a blocked spawn. Recommended: decide with
the comparison; the branch also found #19.

**#4 Relax exactness.** The port is faithful by events and formulas,
not tick by tick (Box2D 3.1 against the 2.3 of LÖVE). Recommended: tag
the current commit `exact`, then relax only what serves exactness
alone, each in its own commit, listed in a document.

**#5 A clock per task or pool** (`doc/compiler.md`, 1): item 33 of the
compiler; the refusal is a check at run time, as in the Lua reference.
`toggle` freezes a subtree; a clock of its own is needed only for
another speed. Not needed by the port.

**#6 E5.** Done (2026-11-21), on the branch `env-sdl`, merged: the port
includes `ext/env-sdl/sdl.atm` (`94cb414`, `tools/setup.sh`), opens its
window (fixed frames of 1/60 s, passes `[:draw, :overlay]`), and draws
over its renderer in `sdl_on_flush`; `eng.slow` is `sdl.clock`; the
events have the names of env-sdl (`:mouse.motion`, `:mouse.button.dn`
`[x,y,button]`, `:key.dn [key,code]`, `:frame [n,us]`); the test
variables are `SDL_ATM_*`, the mouse in window pixels. The mouse keeps
its game position at each of its events (as before: a window that
grows does not move it in the game until it moves). `eg_*` of the
driver, the test script, and `main` left `eng.h` (1213 -> 1040 lines).
The drawing, the sounds (pitch, instances), and the physics stay in the
port. 39 tests identical; `tst/eng/input` prints the new names. See
`doc/bench.md`, "On env-sdl". Before: `env-sdl` was ready: `:frame [n, us]` before the clock,
`sdl.clock(f)` with the carry, the passes `[:draw, :overlay]`,
`sdl_on_flush(f(render))`, frames of exactly 1/60 s. Its plan waits for
#1; the drawing stays in the port.

**#7** Done: the compiler ends `await :all` on an empty pool at once,
and `Quiet` (`src/level.atm`) no longer guards it; same outputs.

**#8 Small differences from the original:**
- #8a done: the window starts at the size of the desktop (or the size
  saved), as the original; at scale 2 in the test mode;
- #8b done: each option plays the sounds of its action in the original
  (`main.lua:1859-2104`), so fewer random numbers are drawn and the
  shake of `tst/game/options2` moved;
- #8c done: the run timer stops for good when the game is won (`not
  self.won` in `Arena:update`); the port counted again after the win;
- #8d done: the shop's texts under the mouse stay, under the dark
  screen of the tutorial (`self.ui:draw()` before it).

**#9** Done: `doc/compiler.md` names the session `atmos-lang` (was "the
compiler session"); the other documents name no session (`pico-sdl`
in `CREDITS.md` and `doc/study.md` is the library the student used).

**#10** Done (`bench.md`, "Memory"): the original decodes its 103
sounds whole at the start (`'static'` sources), 359 MB of samples, 321
MB of them the six songs; streamed, it peaks at 215 MB instead of 946.
The port decodes them too: 546 MB with its audio open.

**#11** The benchmark rerun (`41ae483`): the S7 stress numbers were
measured on a port that did not attack.

**#12** All features of the original but Steam; the first `pin`
migration (`5c489ea`); F5; the single walk of the trail from the
student's port (`4445236`).

**#13** The cost of the migration separated by compiler (`doc/compiler.md`,
10): no difference beyond the spread between `8c9453c`, `8361f88`,
`c4e99c4` and the branch `pin`; most of the extra instructions are
`a_unname_x`, from the loop variable of `separate` (`eng/steer.atm`).

**#14** On `ia-atmos/lang` branch `pin-out` (`8eb364d`, a `set :out`
lasts until its value ends), the branch `contacts-pinout` (`62b759e`)
removes `SHARED_SPRINGS`: each widget lends its spring to a table of
its owner, conditionally; 40 tests identical; no slowdown. Reported to
`atmos-pin`; not to be merged.

**#15** `bench.md` gave 4755 lines for the port (the count of S7,
`51627cd`), `case-study.md` 8647 (S9). Both now give the count at
`7639dd3` with `tools/count.py`: 9455 lines and 91671 tokens for the
game, against 10381 and 134827 for the original (91% and 68%).

**#16** `bench.md`, "The CPU of the logic alone": 0.089 ms per tick in
level 1, 2.77 ms in the stress (medians of three, 1500 ticks, no
window), with the method for other ports.

**#18** `tools/bench/perf.py` ran the port with the disk driver of SDL
on `/dev/null`, which the driver refuses: the port opened no audio,
loaded no sound, and mixed none. With a regular file, at the pace of
the driver: 1.07 to 1.22 times the ticks per second of the original
(not 1.8 to 3.0), 83% to 91% of its CPU (not 56% to 71%), and 546 MB
against 946 MB (not 131). `bench.md` and `case-study.md` are corrected.
To tell the paper.

**#19** The timing of the branch `step` (#3) reached two lines that the
tests of `main` never run, and both failed with `invalid escape`: the
headbutter's color, pinned in an arm of a `match`, given to a tween in
an outer pool, and the randomizer's list of nearby seekers, pinned in a
step of its loop, given to `Sacrifice` in that pool. Fixed on `main`
(the tween in the step of the loop; the list a `val`); the 40 tests are
identical.


**#22** Measured on `90b0d95` (env-sdl `e0aba7b`): the stress logic
(`SNX_PROFILE=1`, no window, no sound, `-O2`, three runs alternated) is
2.985 s at `95b0d0b` against 2.937 s at `7db3c99`; `doc/compiler.md`,
10.

**#23** On `exp-grab`: `main.atm` wraps the screens in a `grabbable` of
the five input events, and `Options` grabs them while it is open; the
time tweens stay outside the grab, so the input comes back at once, as
`close_options`. Lines: `options.atm` 202 -> 208, `main.atm` 100 -> 102.
What did not fit: a grab without a grabbable is an error (three tests
needed their own); a grabbable is a block (the tests pin the arena inside
it and lend it out with `set :out`); the patterns are repeated; the
tutorial stays on `toggle`, since it also freezes time.

**#24** On `exp-context`: `eng.on(c)` gives the enter and leave of a
canvas, and `Stars` and `Background` draw inside a `context`. Stress
logic 2.855 s against 2.973 s (three runs, alternated, the same
compiler), within the spread. Lines: `shared.atm` 115 -> 117,
`eng/eng.atm` 199 -> 213.

**#25** Measured on `main` (Escape at tick 20, click on a card at 42):
gold 3 -> 1, units 0 -> 1. The test `tst/game/grab` of `exp-grab` shows it.
