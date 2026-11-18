# TODO

What is pending in the port of SNKRX (`261111-snkrx.md`): settled items
leave this file, new open ones enter it, in the same commit when
possible. Evaluated again on 2026-11-18.

## A. Decisions waiting for the author

1. The second migration to the rules of `pin`, declared stable at
   `ia-atmos/lang` `1746969` (guide: `.claude/plans/261117-pin-migration-2.md`
   there). The port is at `3a6ffe9` (40 tests green); on `a4c465a` 26
   tests failed at two places (`eng/phys.atm:83`, `src/shop.atm:143`),
   and the static scan of `atmos-lang` lists 36 `pin` to become `val` and
   one `pin var`. Also `X.xin` is now `X.in`. Recommended: yes, now, with
   identical outputs; report once to `atmos-lang`. It is what E5 (B.1)
   waits for.
2. The experiment of a context table owned by the arena (asked by
   `atmos-pin`, 2026-11-17): the world, a map body -> task, and the
   springs in a table pinned in the block of the arena, so a contact is
   emitted only to its two tasks (finding 2), on a branch, not merged
   without the author. Recommended: yes, after A.1.
3. Finding 8 (`doc/compiler.md`): a timer splits the time of a tick,
   so the physics and the movements may take two steps in a tick; the
   original steps once per frame. Recommended: yes, step once per frame
   on an event of game time, after A.1 and A.2; it changes the expected
   outputs of the arena tests, toward the original. `env-sdl` already
   emits `:frame [n, us]` (real time) before the clock, and offers a
   `:step [us]` (the scaled time of the frame) once this is decided;
   until the move, the port can emit its own from `eng.h`.
4. Fidelity and expressiveness: the port is faithful by events and
   formulas, not tick by tick (Box2D 3.1 against the 2.3 of LÖVE). Does
   it count as faithful enough to relax? Recommended: tag the current
   commit (`exact`), then relax only what serves exactness alone, each
   in its own commit, listed in a document.
5. A clock per task or pool (`doc/compiler.md`, 1): item 33 of the
   compiler, not decided; the refusal is a check at run time, as in the
   Lua reference. `toggle` already freezes a subtree; a clock of its
   own is needed only for another speed (slow motion). Recommended: not
   needed by the port.

## B. Work known and not done

1. E5: the move of the platform part of `eng/` to `ia-atmos/env-sdl`.
   The environment is ready for it (E4, Pingus, is done): `:frame [n,
   us]` before the clock, `sdl.clock(f)` with the carry, the passes
   `[:draw, :overlay]`, `sdl_on_flush(f(render))`, fixed frames of
   exactly 1/60 s. Its plan waits for A.1; the drawing (canvases,
   shadows, fonts) stays in the port.
2. After A.1: drop the guard of `await :all` on an empty pool
   (`doc/compiler.md`, 6): the compiler now ends it at once (manual,
   "Await", at `main`).
3. Small differences from the original: the window starts at scale 2,
   not at the size of the desktop; clicks in the options play the
   sounds of the generic button; the run timer does not count during
   the end of a won level; the text under the mouse of the guide hides
   while the tutorial is open.
4. The sessions have new names (`atmos-lang`, `atmos-pin`, `env-sdl`,
   ...); use them in the documents when next touched. This session is
   listed as `sdl-snxkx`, the repository is `ia-atmos/sdl-snkrx`.
5. Why the original peaks at 946 MB was not investigated (`bench.md`).

## C. Reported and not acknowledged

1. The benchmark rerun (`41ae483`): the S7 stress numbers were measured
   on a port that did not attack and are not to be compared.
2. All features of the original are in (but Steam), the first `pin`
   migration (`5c489ea`), F5, and the single walk of the trail from
   the student's port (`4445236`).

## D. Older items

None. Settled since the last evaluation: the compiler checks a spawn
that ends with its block (finding 7, now an error); the clock per task
was answered (A.5); tables built inside a `pin` were superseded by the
new rules and A.2.
