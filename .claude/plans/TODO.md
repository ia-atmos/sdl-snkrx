# TODO

What is pending in the port of SNKRX (`261111-snkrx.md`). Items are
`#N`, unique in this session, in order, never reused; from another
session, `session#N` (this session: `sdl-snxkx`, for the repository
`ia-atmos/sdl-snkrx`). A closed item keeps its number in the index.

## Index

| # | Title | Kind | State |
|---|-------|------|-------|
| #1 | Second migration to the rules of `pin` | decision | done at `c4e99c4`, by the session, to be confirmed |
| #2 | Contacts sent only to their two tasks, with `set :out` | decision | done on the branch `contacts`, not merged: waits for the author |
| #3 | Finding 8: step the physics once per frame | decision | waits for the author |
| #4 | Relax exactness for expressiveness | decision | waits for the author |
| #5 | A clock per task or pool | remark | answered; not needed by the port |
| #6 | E5: move the platform part of `eng/` to `env-sdl` | work | unblocked (after #1) |
| #7 | Drop the guard of `await :all` on an empty pool | work | done |
| #8 | Small differences from the original | work | open |
| #9 | The new names of the sessions in the documents | work | done |
| #10 | Why the original peaks at 946 MB | work | open |
| #11 | The S7 stress numbers are not to be compared | remark | reported, not acknowledged |
| #12 | All features in, the first `pin` migration, F5, the student's trail | remark | reported, not acknowledged |
| #13 | The time of the logic by compiler (`atmos-pin#14`) | work | done, sent to `atmos-pin` |

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

**#2 Contacts sent only to their two tasks.** Done on the branch
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

**#3 Finding 8** (`doc/compiler.md`): a timer splits the time of a
tick, so the physics and the movements may take two steps in a tick;
the original steps once per frame. Step once per frame on an event of
game time: `env-sdl` offers `:step [us]` once this is decided, and
until the move the port can emit its own from `eng.h`. Changes the
expected outputs of the arena tests, toward the original. Recommended:
yes, after #1 and #2.

**#4 Relax exactness.** The port is faithful by events and formulas,
not tick by tick (Box2D 3.1 against the 2.3 of LÖVE). Recommended: tag
the current commit `exact`, then relax only what serves exactness
alone, each in its own commit, listed in a document.

**#5 A clock per task or pool** (`doc/compiler.md`, 1): item 33 of the
compiler; the refusal is a check at run time, as in the Lua reference.
`toggle` freezes a subtree; a clock of its own is needed only for
another speed. Not needed by the port.

**#6 E5.** `env-sdl` is ready: `:frame [n, us]` before the clock,
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
- #8d the text under the mouse of the guide hides during the tutorial.

**#9** Done: `doc/compiler.md` names the session `atmos-lang` (was "the
compiler session"); the other documents name no session (`pico-sdl`
in `CREDITS.md` and `doc/study.md` is the library the student used).

**#10** Not investigated (`bench.md`).

**#11** The benchmark rerun (`41ae483`): the S7 stress numbers were
measured on a port that did not attack.

**#12** All features of the original but Steam; the first `pin`
migration (`5c489ea`); F5; the single walk of the trail from the
student's port (`4445236`).

**#13** The cost of the migration separated by compiler (`doc/compiler.md`,
10): no difference beyond the spread between `8c9453c`, `8361f88`,
`c4e99c4` and the branch `pin`; most of the extra instructions are
`a_unname_x`, from the loop variable of `separate` (`eng/steer.atm`).

