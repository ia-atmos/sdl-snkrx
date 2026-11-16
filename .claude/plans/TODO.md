# TODO

What is pending in the port of SNKRX (`261111-snkrx.md`): settled items
leave this file, new open ones enter it, in the same commit when
possible.

## A. Decisions waiting for the author

1. A warning of the compiler for a spawn with no pool in a nested block
   (`doc/compiler.md`, 7), raised by the `ceu-atmos` session as a
   language decision. Recommended: yes; the port lost its attacks to it
   from S6 to S9, unseen.
2. `doc/compiler.md`, 1: a clock of its own for a task or a pool. An
   emit of time must be global today (`emit @t (10ms)` is refused with
   `invalid emit : expected global`, a check at run time in `a_emit`, at
   `9ad3291`; item 33 of the compiler, not decided). Recommended: allow
   `emit @t (d)` (and `@ts`), which would let the options freeze the
   game while the interface runs, instead of the global `eng.slow`.
3. `doc/compiler.md`, 2: tables built inside a `pin` pinned with it.
   Sent to the `pin` session with context. Recommended: yes.
4. `doc/compiler.md`, 6: `await :all` on an empty pool ends at once?
   Recommended: yes; the port keeps a guard meanwhile.
5. Fidelity and expressiveness: the port is faithful by events and
   formulas, not tick by tick (Box2D 3.1 against the 2.3 of LÖVE, so
   the motion is close, not identical). The new rule (relax exactness
   once fully faithful) needs a decision: does this port count as
   faithful enough to relax? Recommended: tag the current commit
   (`exact`), then relax only what serves exactness alone (the order
   of random numbers, a frame of delay), each in its own commit, listed
   in a document.

## B. Work known and not done

0. The compiler is pinned at `44dbe47` (`tools/setup.sh`): `main` has
   new rules of `pin` (`98ad03a`, e.g. `val t = [1,2]` must be `pin`).
   Moving to them waits for the author's decision.
1. Features: all of the original are in, but Steam (the achievements are
   kept in `state.txt`, and nothing shows them, as in the original).
1b. Finding 8 (`doc/compiler.md`): a timer splits the time of a tick, so
   the physics and the movements can take two steps in a tick. To step
   once per tick changes every arena test: the author decides.
2. Use the new `await(n, :e)` (and `watching n, :e`, `loop on n, :e`)
   where the port counts events by hand.
3. Why the original peaks at 946 MB was not investigated (`bench.md`).
4. Move the platform part of `eng/` to `ia-atmos/env-sdl` when that
   environment is ready (second after Pingus), with identical traces
   and screenshots. Tell the `env-sdl` session early that the shadows
   and outlines are drawn in canvases composed premultiplied, as LÖVE
   does, so a common interface must keep that.

## C. Reported and not acknowledged

1. The benchmark rerun (`41ae483`): the S7 stress numbers were measured
   on a port that did not attack and are not to be compared.

## D. Older items

None.
