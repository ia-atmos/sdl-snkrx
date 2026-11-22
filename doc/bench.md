# The benchmark

The port against the original, in the same container, one after the
other, with the same scripted input and the same seed
(`tools/bench/perf.py`).

## Setup

- Machine: 4 cores of an Intel Xeon at 2.10 GHz, 16 GB, Linux 6.18.
- Both on a virtual display (Xvfb, 960x540, the scale 2 of both), with
  OpenGL over Mesa 25.2.8 (llvmpipe, which renders on the CPU, in
  threads), every frame drawn, no cap on the frames.
- The sound is mixed but not played: the port on the "disk" driver of
  SDL 2.30.0, to a regular file, at the pace of the driver; the
  original on the "null" driver of OpenAL. (Until `7639dd3`, the port
  was run with the disk driver on `/dev/null`, which the driver refuses:
  the port then opened no audio, and loaded and mixed no sound. See
  "An earlier run, with no sound in the port".)
- The original: LÖVE 11.5 with LuaJIT 2.1, in the bench mode of
  `tools/bench/bench.lua` (every loop is one tick of 1/60 s).
- The port: at `7639dd3` (all the features), built with `-O2`, compiler
  `ia-atmos/lang` at `c4e99c4`.
- Each run is a process, measured by `wait4`: the time on the clock, the
  CPU time (user and system, of all of its threads, which includes the
  threads of llvmpipe), and the peak of its resident memory. The display
  server is not measured. Three runs of each; the table has the median.

The scenarios share the input of `tst/original/run1.sh`: "arena run" at
tick 62, the first card of the shop at tick 452, GO at tick 522, and
level 1 from tick 573, with no steering.

- menu: 600 ticks of the menu.
- shop: 720 ticks, the shop from tick 113.
- level 1: 1800 ticks, the arena from tick 573.
- stress: 1500 ticks, as level 1 with 200 more seekers in a grid when
  the arena starts, and units that take no damage, so that the crowd
  lives to the end (`SNX_STRESS=200`, `SNKRX_STRESS=200`).

## Results

| scenario | program | ticks | clock (s) | CPU (s) | ticks/s | peak (MB) |
|----------|---------|------:|----------:|--------:|--------:|----------:|
| menu     | port     |  600 | 10.06 | 16.62 |  60 | 546.7 |
| menu     | original |  600 | 10.78 | 18.35 |  56 | 946.3 |
| shop     | port     |  720 | 10.11 | 17.15 |  71 | 545.9 |
| shop     | original |  720 | 10.98 | 18.96 |  66 | 946.5 |
| level 1  | port     | 1800 | 16.00 | 33.69 | 113 | 546.0 |
| level 1  | original | 1800 | 19.34 | 40.48 |  93 | 946.2 |
| stress   | port     | 1500 | 19.10 | 34.64 |  79 | 546.1 |
| stress   | original | 1500 | 23.10 | 41.32 |  65 | 946.0 |

- Ticks per second: the port runs 1.07 times as many as the original
  in the menu, 1.08 in the shop, 1.22 in level 1, and 1.22 in the
  stress. Both spend most of the short scenarios loading: decoding the
  sounds, the songs above all (about 6 s of the 10 s of the menu of the
  port).
- CPU: the port spends 83% to 91% of the CPU time of the original.
- Memory: the peak of the port is 546 MB, of the original 946 MB, in
  every scenario; both are mostly the sounds, decoded at the start (see
  "Memory").

### An earlier run, with no sound in the port

The runs of S9 (port at `b2c2089`, compiler `995c3b2`) gave 1.8 to 3.0
times as many ticks per second for the port, 56% to 71% of the CPU, and
131 to 141 MB against 946 MB. In them the port ran with the disk driver
of SDL on `/dev/null`, which the driver refuses ("not a regular file"),
so the port opened no audio and loaded none of its sounds, while the
original decoded all of its sounds. Those numbers are not to be
compared.

### A still earlier run, with a port that did not attack

The first runs of this benchmark were at the end of S7 (port at
`f151195`, compiler at `2f45211` and `995c3b2`): 155 to 177 ticks per
second for the port in the first three scenarios (as above), but 74 to
79 in the stress, against 59 to 62 for the original. At that time, the
units of the port never attacked (a task spawned in a loop or an `if`
ended at once, `compiler.md`, 7): the snake took no damage and killed no
seeker, so the crowd of 200 lived to the end, while the snake of the
original killed it. With attacks, 197 seekers die by tick 1500 of the
stress in the port, and the logic has less to do.

## Memory

The original loads its 103 sounds with `love.audio.newSource(path,
'static')` (`engine/sound.lua`), which decodes each file whole at the
start: 359 MB of samples (16 bits), of which 321 MB are the six songs.
After one frame its peak is already 930.6 MB. With its sounds loaded as
`'stream'` instead (a copy of the original, changed only there), the
peak of 60 frames is 214.7 MB, 731 MB less, about two times the decoded
samples (LÖVE keeps the decoded data and OpenAL a copy of it in its
buffer). An empty program of LÖVE with the same window peaks at 138.8
MB.

The port decodes its sounds at the start too (`Mix_LoadWAV`, as the
original's static sources): song 1 alone is 56.8 MB. With its audio
open, the port peaks at 546 MB; with no audio (`SNX_MUTE=1`), at 131.4
MB.

So neither peak is about the language: it is how the sounds are
loaded. Streaming the songs, in either, would remove most of it.

## Where the time of the port goes

`SNX_PROFILE=1` splits the time of a run of the port into its logic (the
reactions of the tasks), its drawing (the lists of shapes), and its
rendering (SDL and OpenGL). The scenarios level 1 and stress, 1500
ticks each, median of three runs:

| | logic (s) | draw (s) | render (s) |
|-|----------:|---------:|-----------:|
| level 1 | 0.23 | 0.35 | 8.10 |
| stress  | 3.90 | 0.56 | 8.57 |

With few objects, the port spends almost all of its time in the
rendering of llvmpipe: the logic of a tick takes about 0.15 ms. With the
crowd, the logic takes about 4 ms per tick in the 927 ticks of the arena,
less as the crowd dies.

The rest of this section was measured on the port of S7, whose units
did not attack, so the 200 seekers lived through the whole stress: it
shows what a crowd that stays costs (9.73 s of logic then).

A profile of the stress with `callgrind` (700 ticks, the last 127 of them
with the crowd) puts 52% of the instructions under `separate`
(`eng/steer.atm`), which visits every other enemy for each seeker, as
the original does (`steering.lua:164-177`, over all the objects of the
classes of the enemies), and 23% under `phys_step` (`eng/phys.atm`),
which sends each contact as an event to all the tasks that await one
(`doc/compiler.md`, 2). The instructions themselves are mostly the
dispatch of events to the tasks (`emit_trail`, `trail_resume`), the
access to tables (`a_index`, `a_tab_get`), and the arithmetic on the
dynamic values of Atmos.

The same with one part switched off (logic of the stress, two runs
each, with no rendering):

| | logic (s) |
|-|----------:|
| as is | 9.35, 8.43 |
| no separation | 6.16, 6.77 |
| no events of the contacts | 10.39, 9.35 |
| neither | 2.46, 2.35 |

The two parts depend on each other, since each changes how the crowd
moves: without the separation, the seekers pile up and touch more
often; without the events, the units do not push the seekers that touch
them, and the seekers do not bounce off the walls. Together, they are
about 70% of the logic of the stress. The original runs the same loop of the
separation in LuaJIT.

## The CPU of the logic alone

The time that the reactions of the tasks take, without drawing or
rendering: the port at `7639dd3` (compiler `c4e99c4`), built with `-O2`,
no window (`SDL_VIDEODRIVER=dummy`), no sound, `SNX_PROFILE=1`, which
measures around the emits of the input, of the real tick, and of the
time (the logic), the emits of `:draw` and `:overlay` (the drawing),
and the rendering,
apart. The scenarios of `tools/bench/perf.py`, 1500 ticks each, three
runs, medians:

| | logic (s) | logic per tick (ms) | runs (s) |
|-|----------:|--------------------:|---------:|
| level 1 | 0.133 | 0.089 | 0.125, 0.133, 0.149 |
| stress (200 more seekers) | 4.161 | 2.77 | 4.099, 4.161, 4.182 |

The per tick is over all 1500 ticks of the run, the menu and the shop
included; in the stress, the crowd is in the arena from tick 573 on.
To measure another port the same way: the same scripted input and
number of ticks, the time of the reactions to the events of a frame
alone, with no window, and the median of three runs.

## On env-sdl (sdl-snxkx#6)

Since the move to env-sdl, the window, the loop, the events, the time,
and the test mode are those of `ia-atmos/env-sdl` (`94cb414`), and the
port draws over its renderer at the end of each frame. The same
scenarios as above, the port of `main` before the move (`ad37d31`)
against the port on env-sdl (`82ce653`), both with the compiler
`7db3c99`, `-O2`, OpenGL over Xvfb, sound mixed to a file,
`SNX_PROFILE=1`, three runs each, alternated, medians:

| scenario | build | clock (s) | CPU (s) | ticks/s | peak (MB) | logic (s) |
|----------|-------|----------:|--------:|--------:|----------:|----------:|
| menu | before | 8.25 | 14.09 | 73 | 545.2 | 0.167 |
| menu | env-sdl | 8.77 | 15.32 | 68 | 545.9 | 0.226 |
| shop | before | 9.00 | 16.03 | 80 | 546.0 | 0.073 |
| shop | env-sdl | 9.05 | 15.78 | 80 | 545.4 | 0.122 |
| level 1 | before | 15.14 | 32.45 | 119 | 545.2 | 0.342 |
| level 1 | env-sdl | 15.66 | 33.62 | 115 | 545.6 | 0.468 |
| stress | before | 16.62 | 31.49 | 90 | 545.4 | 3.171 |
| stress | env-sdl | 18.07 | 34.46 | 83 | 545.6 | 3.470 |

The outputs of the 40 tests are the same. On env-sdl, the logic is
measured from `:frame` to `:draw` (the reactions to `:frame` and to the
time, and the clear of the window by env-sdl), not around the input
as before. Of the 1.45 s more on the clock in the stress, 0.82 s is the
clear of the window that env-sdl does before the passes of drawing,
which the composition of the port then covers: without it (a local
patch of `sdl.atm`, not committed), the stress takes 17.34 s instead of
18.16 s, and the logic 3.305 s instead of 3.468 s (three runs each,
alternated).

With the option of env-sdl that skips the clear (`sdl.window
[clear=false]`, env-sdl `e0aba7b`), adopted by the port, the stress
took 18.42 s against 18.62 s with the clear (three runs each,
alternated, the same machine: 18.76, 18.42, 17.38 against 19.22, 18.58,
18.62), CPU 34.40 s against 35.40 s. The gain is smaller than the
0.82 s of the local patch above and within the spread of the runs. The
outputs of the 40 tests are the same.

### Where the 1.45 s went (TODO #21)

The same stress, with the window, three runs of each build alternated
on the same machine, each build with the same compiler. `SNX_PROFILE`
splits logic, drawing and rendering; "other" is the clock minus the
three (the input, the present, and the rest of the loop: on env-sdl the
present is no longer inside "render").

| compiler | build | clock (s) | logic | draw | render | other |
|----------|-------|----------:|------:|-----:|-------:|------:|
| `7db3c99` | before the move (`ad37d31`) | 16.94 | 3.30 | 0.62 | 7.42 | 5.57 |
| `7db3c99` | on env-sdl, with the clear (`82ce653`) | 17.85 | 3.59 | 0.65 | 5.79 | 7.83 |
| `7db3c99` | on env-sdl, `clear=false` (`main`) | 17.15 | 3.26 | 0.60 | 4.61 | 8.63 |
| `95b0d0b` | before the move (`ad37d31`) | 16.28 | 3.26 | 0.59 | 7.07 | 5.41 |
| `95b0d0b` | on env-sdl, `clear=false` (`main`) | 16.41 | 3.17 | 0.58 | 4.37 | 8.31 |

(medians; the ranges of the clock: 16.48 to 16.99, 17.40 to 18.04,
16.81 to 17.16, 16.16 to 16.50, 16.12 to 16.65.)

The gap was real at the move (0.91 s here), and `clear=false` took 0.70
s of it: the clear made the composition of the canvases slower (render
5.79 s against 4.61 s), more than the 0.20 s that one pair of runs had
shown above. What is left is 0.13 s to 0.21 s, at the edge of the
spread of the runs, in rendering and presenting (render plus other:
13.0 s before, 13.2 s on env-sdl with `7db3c99`); the logic is the same
(3.17 s to 3.30 s). The 0.63 s that seemed not to be the clear was the
clear too: one measure of it, by a local patch, had found less than the
whole.

## Size of the code

Lines of code (no blanks, no comments) and tokens, with
`tools/count.py`, the same count as `case-study.md`: the port at
`7639dd3`, the original at `6b93a64` as committed (its files without the
patch of the benchmark).

| | lines | tokens |
|-|------:|-------:|
| original, the game (`main`, `arena`, `buy_screen`, `enemies`, `player`, `objects`, `shared`, `mainmenu`, `media`, `conf`) | 10381 | 134827 |
| original, its engine (`engine/`, without `engine/external`) | 4428 | 40796 |
| port, the game (`src/`, `main.atm`) | 9455 | 91671 |
| port, its engine (`eng/`, Atmos and C) | 2209 | 19370 |
| port, its engine on env-sdl (`82ce653`; env-sdl not counted) | 2048 | 18037 |

An earlier version of this table (`51627cd`, S7) gave 4755 lines and
43606 tokens for the game of the port, which then had ten characters,
four elites and a boss, the levels, and the shop, with no passives or
items; and 10374 lines for the original, without `conf.lua`.
