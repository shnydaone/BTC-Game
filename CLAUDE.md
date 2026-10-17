# CLAUDE.md

Project brief for Claude Code. Read this first, then `docs/GDD.md` for the full design.

## What this is

**Proof of Work** (working title): a real-time Bitcoin mining business simulation. The player follows Bitcoin from the Genesis block, builds a mining company from a single laptop to a public company, survives every crash, then plays an endless branching future. Pixel art, desktop only, Godot 4.x with GDScript.

## Current milestone

**M2: Headless sim.** M1 Data is done (history CSV, events, hardware, each with a validator in `tools/`). M2 lands in three PRs: (1) Godot scaffold, GUT, data loading, consensus, RNG and the anchored-chain network; (2) mining, hardware, sites, power, finance, market, custody, treasury, events, objectives, restructuring; (3) bots and the golden and outcome tests. Do not start building UI or art before M2 passes its bot tests.

## Locked decisions

Do not change these without Eric's explicit approval. Record any new locked decision in `docs/decisions.md` with the date and the reason.

- Real-time with pause and speed controls. The sim ticks once per game day.
- Desktop only. Base resolution 640×360, integer scaling, nearest filtering, 16px tile grid.
- Audience: Bitcoiners, with teach-as-you-play.
- Campaign: Acts 1-4 run from the Genesis block (2009-01-03) to the fourth halving (2024-04-20), about 5 hours. Act 5 is an endless procedural future.
- Entry modes: Cypherpunk (mine from Genesis), Slashdot (default: a fast prologue, mining unlocks 2010-07-11), Late to the party (starts at halving 1, 2012-11-28). Scores are compared within a mode only.
- Anchored chain: blocks per day and height come from history. The player's hashrate takes a share of those blocks and drives an effective difficulty readout, so halvings and dated events never drift.
- Halvings are act breaks. Each act has scenario objectives.
- Failure means restructuring (Chapter 11). The player keeps playing, diluted. Below 10% ownership, the act is lost.
- Future: a macro scenario rolled at the 2024 halving, plus light player influence.
- Rivals: faceless network hashrate in Acts 1-2, named parody companies from Act 3.
- Tone: Bitcoin culture humor in flavor text, honest economics in the numbers, an anonymous mentor for teaching.
- Charts: an always-on price ticker plus cinematic event replays.

## Repo layout

```
res:// (Godot project root: project.godot at the repo root)
  addons/gut/ GUT 9.7.1, vendored
  autoload/   game_clock.gd, event_bus.gd, data.gd, save.gd
  sim/        pure simulation classes (no Nodes)
  data/       history/ (CSV), events/, hardware/, protocol/ (consensus facts), tuning/ (JSON feel values)
  scenes/     main, facility, ui, charts
  assets/     sprites, tiles, fonts, audio, palette
  tests/      unit/, sim/
tools/        Python data prep scripts
docs/         GDD.md, decisions.md, art-bible.md, sprite-prompts.md
```

## Architecture rules

- **The sim is pure.** Everything in `sim/` extends RefCounted, has no Node or scene dependencies, and runs headless. Single entry point: `Sim.step_day()`.
- **Presentation listens.** Scenes and UI react to `EventBus` signals. They never calculate economics.
- **Deterministic.** All randomness goes through `sim/rng.gd` with a seed.
- **No hardcoded tuning.** Every economic and feel number lives in `data/`. If you find yourself typing a magic number into `sim/`, move it to data. Protocol facts go in `data/protocol/`, judgment calls in `data/tuning/` with a unit, a basis and a note.
- **No network calls at runtime.** No live prices, wallets, exchanges or APIs. Historical data is committed as CSV.

## Code conventions

- GDScript with static typing everywhere (`var x: float`, typed function signatures).
- snake_case files and functions, PascalCase `class_name`s.
- Signals are named in past tense (`block_found`, `difficulty_adjusted`, `covenant_breached`).
- One system per file in `sim/`.

## Testing

- Unit test framework: GUT 9.7.1 (the release built for Godot 4.7), vendored in `addons/gut`.
- Godot 4.7.2 is installed at `C:\Program Files\Godot\` and is not on PATH. Use the `_console` build so output and exit codes reach the terminal, or set `GODOT` and run `powershell -File tools/test.ps1`.
- On a fresh clone, run the import pass once so `class_name` scripts register:
  `godot --headless --path . --import`
- Run tests headless before every commit (`-ginclude_subdirs` is needed for `tests/unit` and `tests/sim`):
  `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- Validate data after editing it: `python tools/check_events.py`, `python tools/check_hardware.py`, `python tools/check_tuning.py`.
- CI (`.github/workflows/tests.yml`) runs the validators, the import pass and GUT headless on every push to main and every pull request.
- Player actions go through `Sim.apply(command)` (`sim/commands.gd`); bots and UI use the same commands. `SimState.hashrate_override_hs` replaces the fleet's hashrate for tests and the debug panel.
- Bot balance runs (to be built in M2) play the whole campaign headless and write CSV summaries:
  `godot --headless --script res://tests/sim/run_bots.gd`
- See GDD section 14 for the expected bot outcomes. A change that breaks an expected outcome is a balance regression. Flag it, don't silently retune.

## Art pipeline (PixelLab)

- Generate art through the PixelLab MCP server when it's configured.
- Respect the style lock (once made in M4): palette in `assets/palette`, 16px grid, base resolution 640×360.
- Log every prompt that produced a kept asset in `docs/sprite-prompts.md`: the exact prompt, size, settings, and any failure notes.
- Import settings for all pixel art: filter Nearest, mipmaps off, lossless compression.

## Content rules

- Real historical events are stated factually in news and event cards.
- Exchanges, lenders, hosts, hardware makers and rival companies the player deals with use parody names.
- No real people's likenesses or portraits. The mentor is faceless.
- No financial advice framing. No tokens, NFTs or live crypto.
- No em dashes in game text or docs. Use periods, commas, colons or parentheses.

## Workflow with Eric

- Before a large change, post a short summary of what you're about to do and wait for a go-ahead.
- Ask when something is unclear or when more input would improve the result.
- Double check work: run the tests, run the game, read back generated files.
- Commit messages: a short, copiable title line, a blank line, then a separate body.
- Push back when a plan or request looks off. Don't soften disagreement into agreement.
