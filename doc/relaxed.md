# Relaxed exactness

The port was first made faithful to SNKRX (`6b93a64`) by events and
formulas: the branch `exact` (`58594e4`) keeps that version. On `main`,
some code that existed only to reproduce the original bit by bit is
replaced by a more direct form (`sdl-snxkx#4`, approved by the author on
2026-11-21).

The criterion: what the player sees and does is kept (the intent of the
original author: the rules, the formulas, the delays as numbers in the
source, the look); what goes is exactness that no player can see (in
which tick of 1/60 s a delay ends, a rounding).

## Deliberate differences

| # | What was given up | What was gained | Lines | Tests whose outputs changed |
|---|-------------------|-----------------|-------|-----------------------------|
| R1 | A wait in real time ended a tick after its duration for most durations, as the original's `after(d)`, which tests `timer > d` on a sum of floats | `WaitReal(s)` is one counted await, `await(math.floor(s*60 + 0.5), :tick)`, instead of a loop that sums the floats of the original | `WaitReal`: 7 lines to 3 | 9 traces, one or two ticks earlier (`allpassives`, `boss`, `chars`, `elites`, `gold`, `level`, `menu`, `passives`, `run`; the scripted `run` follows another path through level 1, which it still clears); 8 screenshots |
| R2 | A tween of the interface (real time) ended in the first tick past its duration, and could overshoot its values by a tick, as the original | `TweenReal` counts whole microseconds, clamps the time to the duration, and ends at it, with the fields at their values; it no longer needs `tick_dt` | 13 lines to 16 | 3 traces (`arena3`, `bosses`, `options2`: a tick earlier, then the physics diverges by tenths of a pixel); 18 screenshots |
| R3 | The run timer added the floats of the original (`tick_dt`: 1/60 s, rounded from the microseconds of the tick) | The timer adds the real microseconds of each tick; `tick_dt`, used by nothing else after R1 and R2, is gone | 10 lines to 1 | none |

## Candidates rejected

| Candidate | Where | Why it stays |
|-----------|-------|--------------|
| The names of the random functions (`rfloat`, `rint`, `rtable`, `rbool`, `rweighted`), as `Random` of the original | `eng/random.atm` | Not an exactness: a small vocabulary that reads well. The order of the calls to the generator is not kept anyway (Box2D differs). |
| The springs of the interface update in every tick, even at rest | `eng/anim.atm` (`UISprings`) | Stopping them when they converge (as the student's port did) adds code to wake them on a pull: less clear, for no visible gain. |
| `Every` keeps what passes beyond the delay, and reads the attack speed in every tick | `src/attack.atm` | A rule of the game: the attack speed may change during a wait, and the rhythm of the attacks depends on the carry. |
| `Cooldown` and `BossAttack` sum the time by hand | `src/attack.atm`, `src/elite.atm` | The sum drives a bar on the screen (`u.cooldown`, `e.attack_ratio`): it is visible. |
| The `trace` lines | `eng/eng.atm` and 27 calls | They are the tests, not an imitation of the original. |
| `Tween` in game time ends in the first tick past its duration (as R2 does for `TweenReal`) | `eng/anim.atm` | Tried: ending the tweens of the game a tick earlier shifts the order of the random draws in every arena, and the tests that rely on chance lose what they show (no gold drops in `chars3`, no barrage of the cannoneer in `chars2`, no crit of the outlaw in `classes`). The gain, a tick, is not worth the coverage. |
| The muted music awaits forever instead of drawing random numbers | `main.atm` | It keeps the tests deterministic; nothing of the original. |
