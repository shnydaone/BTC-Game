# Decision Log

Locked decisions, newest at the bottom. Format: date, decision, reason.

| Date | Decision | Reason |
|---|---|---|
| 2026-10-16 | Concept: Bitcoin mining tycoon as a business simulation | Real protocol rules (halvings, difficulty adjustment) make natural game mechanics; plays to finance strengths; light art load |
| 2026-10-16 | Engine: Godot 4.x, GDScript; art: PixelLab | Eric's chosen toolchain |
| 2026-10-16 | Real-time with pause and speed controls | Classic tycoon feel |
| 2026-10-16 | Desktop only | UI-heavy sim; mobile would constrain layout |
| 2026-10-16 | Audience: Bitcoiners, teach as you play | Inside jokes land, jargon never blocks |
| 2026-10-16 | Win condition: per-act scenario objectives, ~5 hour campaign, endless future | Clear goals in history, replayability after |
| 2026-10-16 | Failure: restructuring (Chapter 11), not game over | Mirrors 2022 miner bankruptcies; failure teaches instead of reloads |
| 2026-10-16 | Future: macro scenario roll plus light player influence | Runs feel different; player size matters |
| 2026-10-16 | Rivals: faceless early, named parody companies from Act 3 | Keeps early game simple; enables bankrupt-rival acquisitions |
| 2026-10-16 | Tone: culture humor plus anonymous mentor | Mentor teaches, humor carries the culture |
| 2026-10-16 | Charts: always-on ticker plus cinematic event replays | Crashes and spikes are the emotional beats |
| 2026-10-16 | Difficulty adjustments do not auto-pause by default | ~400 adjustments in the campaign would wreck pacing |
| 2026-10-16 | Hardware ladder: 12 units calibrated on real hardware, adding Gen 2b (S7 class, 2015) and Gen 3b (S17 class, 2019) and splitting Gen 5 into S19 XP and S21 classes; GPUs modeled per card | Closes multi-year gaps with one machine and keeps real efficiency jumps; facts in data/hardware, feel values in tuning |
| 2026-10-16 | Anchored chain: blocks per day and height come from btc_daily.csv; the player's hashrate takes a share of those blocks and drives an effective difficulty readout | The real retarget rule with player hashrate added pulls halvings 1 to 4 months early (almost all of it from 2009, when the network sat below the difficulty-1 floor), which moves act breaks and dated events off history. Cost: a 2009 laptop earns about 13% less than under the strict rule; negligible from 2010 |
| 2026-10-16 | Entry modes: Cypherpunk (mine from Genesis), Slashdot (default; clock starts at Genesis with a fast prologue, mining unlocks 2010-07-11), Late to the party (starts at halving 1, 2012-11-28) | A laptop mining from Genesis holds about 278,000 BTC by end-2010; from the Slashdot story, about 320. Each mode is honest history with a different starting point, and the whale becomes an honestly labeled easy mode |
| 2026-10-16 | Scores are compared within a mode only; the score formula (owner's equity x ownership) is unchanged | Whales compete with whales, so no score rework is needed |
| 2026-10-16 | Slashdot prologue: a fast montage with a few choices (household setup, mentor posts, Codex), skippable on replay | Teaches the USD side of the loop before mining exists, without dead air |
| 2026-10-16 | Pizza Day is a news headline unless the player holds the coins (Cypherpunk); forum trade offers appear once the player mines, with the regret counter on what they spend | Slashdot and Late players have no coins on 2010-05-22 |
| 2026-10-16 | Test framework: GUT, vendored and pinned (9.7.1 for Godot 4.7) | Pure GDScript, one-line headless CLI, enough for a logic-only sim. Closes GDD open question 6 |
| 2026-10-16 | Tuning lives in data/tuning/*.json (value, unit, basis, note per entry); protocol facts in data/protocol/consensus.json with sources | Diffable, validated by tools/check_tuning.py like the M1 data, easy to dump from a debug panel. Replaces the tuning.tres in GDD 13 |
| 2026-10-16 | Money: BTC in integer satoshis, USD in integer cents | No rounding drift over 5,800 simulated days |
| 2026-10-16 | Bot outcomes are asserted in Slashdot mode over Acts 1-2 in M2; other modes get sanity checks; the Max Leverage 2018/2022 outcome moves to M6 | M2 builds only the Acts 1-2 finance; Max Leverage gets an interim 2014-2015 expectation |
| 2026-10-17 | Living costs are personal: unpaid living costs are a missed payment in every act, never company debt or a Chapter 11 trigger | A bot probe showed a solvent-on-paper company restructured monthly over the founder's rent and groceries |
| 2026-10-17 | Unpaid company obligations start a 14-day cure clock before Chapter 11 | GDD 7.7 already has cure clocks for covenants; without one, a company holding 50 BTC in cold storage went bankrupt over $300 of rent before it could move coins |
| 2026-10-17 | CPU speedup in 2010: one sourced event, Bitcoin 0.3.6 (2010-07-29), 2.4x for the CPU tier | Release notes state a 2.4x total generating speedup. The 4-way SSE2 patch and early cpuminer made Core 2 CPUs slower or no faster, so they are not modeled |
| 2026-10-17 | A second exchange (exchange_tier4, Bitstamp class) opens 2011-08-18 and survives Acts 1-2 | Players need somewhere to trade after Mt. Gox fails in 2014; Bitstamp launched in August 2011 and kept operating |
| 2026-10-17 | Act 2's hashrate objective is met when the running hashrate reaches the target on any day of the act | GDD 6 says "hit a hashrate target". A sensible miner idles obsolete machines before a halving, so an end-of-act snapshot punished good play |
| 2026-10-17 | Hindsight is the only bot allowed to read future history; bot strategy constants live in the bot scripts, not data/tuning | Bots are test tooling, not game tuning |
