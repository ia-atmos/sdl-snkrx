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

## Candidates rejected

| Candidate | Where | Why it stays |
|-----------|-------|--------------|
| The names of the random functions (`rfloat`, `rint`, `rtable`, `rbool`, `rweighted`), as `Random` of the original | `eng/random.atm` | Not an exactness: a small vocabulary that reads well. The order of the calls to the generator is not kept anyway (Box2D differs). |
| The springs of the interface update in every tick, even at rest | `eng/anim.atm` (`UISprings`) | Stopping them when they converge (as the student's port did) adds code to wake them on a pull: less clear, for no visible gain. |
| `Every` keeps what passes beyond the delay, and reads the attack speed in every tick | `src/attack.atm` | A rule of the game: the attack speed may change during a wait, and the rhythm of the attacks depends on the carry. |
| `Cooldown` and `BossAttack` sum the time by hand | `src/attack.atm`, `src/elite.atm` | The sum drives a bar on the screen (`u.cooldown`, `e.attack_ratio`): it is visible. |
| The `trace` lines | `eng/eng.atm` and 27 calls | They are the tests, not an imitation of the original. |
| The muted music awaits forever instead of drawing random numbers | `main.atm` | It keeps the tests deterministic; nothing of the original. |
