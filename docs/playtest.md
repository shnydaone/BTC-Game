# M3 playtest: the proof-of-fun session

The M3 gate (GDD 15.1) is a human test: a 30-minute session you want to keep playing, with at least one meaningful decision every 2 real minutes. This checklist keeps sessions comparable.

## Setup

1. Pull `main` and run `godot --path .` (or press Play in the editor).
2. Start a new game in **Slashdot** mode. Skip the prologue only if you have played it before; note which.
3. Press **F3** to show the decision meter. It counts every successful command and every card choice with real alternatives ("Continue" does not count).
4. Set a 30-minute timer. Play normally: pause, speed up, read cards, buy and sell as you like.

The meter also writes a log for every session to `%APPDATA%\Godot\app_userdata\Proof of Work\playtest\session_<time>.csv` (seconds, game date, decision).

## During the session

Jot a line whenever:

- you are bored or waiting for something (note the game date and speed),
- you are confused by a number, a card or a button,
- you make a choice that felt real, or one that felt obvious,
- something feels wrong about the economics (too easy, too punishing, too lucky).

## After 30 minutes

Record:

| Question | Answer |
|---|---|
| Did you want to keep playing? (yes / no / maybe) | |
| Game date reached, and how many acts | |
| Meter: decisions per 2 min (gate: 1.0) | |
| Meter: longest gap without a decision | |
| Best moment | |
| Most boring stretch (dates) | |
| Most confusing thing | |
| Felt unfair or unrealistic | |
| Quit the day job? When? | |

## Known balance questions to watch

From `docs/reports/m2-bot-results.md`:

- **GPU whales:** a garage of GPU cards in 2010-2011 can mine over 100,000 BTC. Does Act 2 still feel constrained?
- **Liquidity:** the sell cap barely binds at the June 2011 peak. Can you cash out too easily?
- **Pacing:** Act 1 from the Slashdot story is about 29 minutes of pure 1x ticking. Where do you speed up, where do you stop?

## Tuning between sessions

**F12** opens the tuning panel: pick a file, edit a value as JSON, Apply. The running game picks it up at once. "Dump to file" writes every tuning file to `user://tuning_dump/` to copy into `data/tuning` once a change should stick. Record any change you try in the session notes.
