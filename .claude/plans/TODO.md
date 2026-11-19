# TODO

What is pending in the port of SNKRX (`261111-snkrx.md`). Items are
`#N`, unique in this session, in order, never reused; from another
session, `session#N` (this session: `sdl-snxkx`, for the repository
`ia-atmos/sdl-snkrx`). A closed item keeps its number in the index.

## Index

| # | Title | Kind | State |
|---|-------|------|-------|
| #1 | Second migration to the rules of `pin` | decision | waits for the author |
| #2 | Contacts sent only to their two tasks, with `set :out` | decision | waits for the author and for `set :out` on main |
| #3 | Finding 8: step the physics once per frame | decision | waits for the author |
| #4 | Relax exactness for expressiveness | decision | waits for the author |
| #5 | A clock per task or pool | remark | answered; not needed by the port |
| #6 | E5: move the platform part of `eng/` to `env-sdl` | work | after #1 |
| #7 | Drop the guard of `await :all` on an empty pool | work | after #1 |
| #8 | Small differences from the original | work | open |
| #9 | The new names of the sessions in the documents | work | open |
| #10 | Why the original peaks at 946 MB | work | open |
| #11 | The S7 stress numbers are not to be compared | remark | reported, not acknowledged |
| #12 | All features in, the first `pin` migration, F5, the student's trail | remark | reported, not acknowledged |

## Items

**#1 Second migration to the rules of `pin`** (declared stable by the
author; guide: `.claude/plans/261117-pin-migration-2.md` in
`ia-atmos/lang`). The port is at `3a6ffe9`, 40 tests green. At `8c9453c`
a compile pass gives 35 warnings `pinned value given away by its block
(expected 'val')` and one `pin var` (`src/classes.atm:71`); on
`a4c465a` 26 tests failed at `eng/phys.atm:83` and `src/shop.atm:143`.
Also `X.xin` is now `X.in`. Recommended: yes, now, outputs identical, at
`8c9453c` or later, with the time of the frame loop measured; report to
`atmos-pin`.

**#2 Contacts sent only to their two tasks.** Answered by `atmos-pin`
(2026-11-19, tested on `ia-atmos/lang` branch `pin` `4199167`): the
new `set :out place = value` lets a table owned outside the task
`Arena` (the world `A.w`, made by the caller) refer to tasks of a pool
inside it; the place goes back to nil at the end of the block where it
is written. So each body task writes `set :out A.w.tasks@(b) = task`
in its own body, `phys_step` emits `emit @(A.w.tasks@(b))` to the two
tasks only, the world stays where it is, and the 21 filters
`until it.b == c.b` go. `SHARED_SPRINGS` goes too: a child writes
`set :out w.springs@(b) = spring` into a table its owner gave it.
`send` stays (a targeted emit is already the direct form). The context
table pinned in the arena's block is not needed. Waits for: `set :out`
on main (`atmos-lang#81`, the author's word), and #1 first.
Recommended: yes, on a branch, with identical outputs, the cost of
contacts measured in the stress benchmark; report to `atmos-pin`.

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

**#7** The compiler now ends `await :all` on an empty pool at once
(manual, "Await"); the port's guard (`doc/compiler.md`, 6) can go.

**#8 Small differences from the original:**
- #8a the window starts at scale 2, not at the size of the desktop;
- #8b clicks in the options play the sounds of the generic button;
- #8c the run timer does not count during the end of a won level;
- #8d the text under the mouse of the guide hides during the tutorial.

**#9** `atmos-lang` (was `ceu-atmos`), `atmos-pin`, `env-sdl`, ...: use
them in the documents when next touched.

**#10** Not investigated (`bench.md`).

**#11** The benchmark rerun (`41ae483`): the S7 stress numbers were
measured on a port that did not attack.

**#12** All features of the original but Steam; the first `pin`
migration (`5c489ea`); F5; the single walk of the trail from the
student's port (`4445236`).
