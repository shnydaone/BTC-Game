# Proof of Work (working title): Game Design Document

Version 0.1 (Phase 0 pitch) · ShnydaSoft · October 2026

---

## 1. Snapshot

| | |
|---|---|
| **One-liner** | Follow Bitcoin from the Genesis block, build a mining company from a single laptop to a public company, and survive every crash along the way. |
| **Genre** | Real-time business simulation / tycoon |
| **Platform** | Desktop (Windows, macOS, Linux) |
| **Engine** | Godot 4.x, GDScript |
| **Art** | Pixel art generated with PixelLab, top-down 3/4 facility view plus a finance dashboard |
| **Audience** | Bitcoiners. The game teaches as you play, so it never stalls on jargon. |
| **Campaign** | About 5 hours of historical play (Genesis block to the 2024 halving), then an endless branching future |
| **Status** | M2: headless simulation in progress. |

## 2. Locked decisions

| Decision | Choice |
|---|---|
| Concept | Mining tycoon framed as a business simulation |
| Time model | Real-time with pause and speed controls |
| Platform | Desktop only |
| Audience | Bitcoiners, with teach-as-you-play |
| Win condition | Scenario objectives per act, campaign about 5 hours, endless future afterward |
| Failure | Restructuring (Chapter 11). You keep playing, diluted. |
| Future | Macro scenario rolled at the 2024 halving, plus a light layer of player influence |
| Rivals | Faceless network hashrate early, named parody rival companies from Act 3 |
| Tone | Bitcoin culture humor on top of honest economics, with an anonymous mentor as the teaching device |
| Charts | Always-on price ticker plus cinematic replays of major crashes and spikes |
| Entry modes | Cypherpunk (mine from Genesis), Slashdot (default, mining from 2010-07-11), Late to the party (from halving 1). Scores compared within a mode |
| Chain model | Anchored chain: block counts come from history, the player takes a share of them |

## 3. Design pillars

1. **Real rules are the mechanics.** Halvings, the difficulty adjustment, hashprice, fees and custody risk are the economy, not flavor text.
2. **Survive the cycle.** Bull markets tempt you to overexpand. Bear markets punish it. Leverage plus a price drop plus rising difficulty is the classic way miners die.
3. **Every number earns a decision.** If a figure on screen does not change what the player does, it gets cut or hidden behind a tooltip.

## 4. Core loop

```
Acquire capacity (hardware, sites, power)
        ↓
Mine BTC (your share of network hashrate × block reward + fees)
        ↓
Treasury decision (sell to cover costs, or HODL)
        ↓
Manage cash, custody and debt
        ↓
Reinvest, retrench, or restructure  →  back to the top
```

**The central tension:** revenue arrives in BTC and swings with the market. Costs (power, rent, salaries, debt service) are owed in dollars and do not care about the price. Almost every interesting decision comes out of that mismatch.

## 5. Time and pacing

- **Simulation tick:** one game day. All economic math runs daily.
- **Speeds:** pause, 1x (1 game day per 2 real seconds), 2x, 4x, 8x. Values live in tuning data.
- **Prologue (Slashdot mode):** Jan 3, 2009 to Jul 11, 2010 plays as a fast montage of about 3 to 5 minutes with a few choices: household setup (savings, rent, salary), the mentor's mailing list posts, headlines and Codex unlocks. Skippable on replay. Mining unlocks with the Slashdot story on Bitcoin 0.3.
- **Campaign math:** Jan 3, 2009 to Apr 20, 2024 is about 5,586 days, or about 3.1 hours of pure 1x ticking. Players fast-forward quiet stretches and spend time paused in decisions and replays. Target median playthrough is about 5 hours, about 1 hour per act. Tune with playtests.
- **Auto-pause on:** major historical events (cinematic replay), decisions with deadlines, margin calls and covenant breaches, act end.
- **Difficulty adjustments:** shown as a non-blocking toast with the % change. Optional auto-pause in settings, off by default. (Correction to the earlier planning lean: there are roughly 400 adjustments in the campaign, so pausing on every one would wreck the pacing.)

## 6. Acts and campaign objectives

Halvings are the act breaks. Each act ends with a report card: owner's equity in USD and BTC, objectives met, grade.

| Act | Dates | Theme | Unlocks | Primary objective | Bonus objectives |
|---|---|---|---|---|---|
| 1. Genesis | 2009-01-03 → 2012-11-28 | A hobby with a day job | Bedroom, garage, CPU, GPU, FPGA, solo then pool mining, first exchange | **Quit your day job:** mining revenue covers living costs for 90 straight days | Survive the 2011 crash without selling; a forum trade offer decision |
| 2. Arms Race | 2012-11-28 → 2016-07-09 | Hardware obsolescence | ASICs, warehouse, incorporation, small business loan | Hit a hashrate target (tuned) and finish the act solvent | Lose nothing to exchange failures |
| 3. Industrial | 2016-07-09 → 2020-05-11 | Scale and power | Regions and power contracts, CFO hire (full statements), equipment financing, futures hedging, rivals appear | Build your first owned facility and get through 2018 and Black Thursday without restructuring | Finish with the lowest all-in cost per BTC among rivals |
| 4. Institutional | 2020-05-11 → 2024-04-20 | Capital markets | IPO window, BTC-backed loans, relocation after the China ban, acquisitions | Go public and finish 2022 without restructuring | Acquire a bankrupt rival |
| 5. Future | 2024-04-20 → endless | Branching macro scenario | Scenario event decks, lobbying, grid services | None. Score keeps running. | Survive each new halving |

### 6.1 Entry modes

The history is the same in every mode. Only the player's starting point changes, and scores are compared within a mode only.

| Mode | Clock starts | Mining | Notes |
|---|---|---|---|
| Cypherpunk | 2009-01-03 | From Genesis | Easy mode, labeled honestly. A laptop left on through 2009 holds about 278,000 BTC by end-2010. |
| Slashdot (default) | 2009-01-03 | From 2010-07-11 | Fast prologue (section 5). A laptop from the Slashdot story holds about 320 BTC by end-2010. Mining, Mt. Gox and selling all arrive within a week. |
| Late to the party | 2012-11-28 | From the start | Starts at halving 1, the first day of Act 2. Skips Act 1 and the mentor. Hard mode. |

Mode settings live in `data/tuning/modes.json`.

## 7. Systems

### 7.1 Mining math

One model runs for the entire game: an **anchored chain**. In historical acts, blocks per day, chain height, difficulty and the world's hashrate all come from real data. The player's hashrate is added to the world's, and the player takes a share of the blocks history actually found. Halvings and every dated event therefore land on their real dates.

- `blocks_per_day` = the historical count for that day (it runs above 144 while hashrate grows faster than difficulty adjusts, which is accurate)
- `network_hashrate = world_hashrate + player_hashrate`
- `share = player_hashrate / network_hashrate`
- **Effective difficulty** (a readout): at each historical retarget, history's new difficulty scaled by the epoch's (world + player) / world hashrate, clamped to 4x either way and never below 1. It shows how the player's own hashrate raises difficulty. It does not change rewards.
- Why not the strict rule: with the player's hashrate added under the real 2,016-block rule, extra blocks pile up in 2009 (the network sat below the difficulty-1 floor) and the halvings land 1 to 4 months early, which moves act breaks and dated events. The anchored chain costs a 2009 laptop about 13% of its strict-rule earnings and is negligible from 2010 (decisions.md, 2026-10-16).
- **Solo mining:** blocks found per day ~ Poisson(`share × blocks_per_day`), each paying `subsidy + fees_per_block`. Lumpy and exciting. "You found a block!"
- **Pool mining** (unlocks Dec 2010): `share × blocks_per_day × (subsidy + fees_per_block) × (1 − pool_fee)`, paid daily. Smooth. Teaches variance versus expected value.
- `power_cost_per_day = Σ(unit_watts × uptime) × 24 / 1000 × price_per_kWh × PUE`
- `hashprice = USD revenue per day / TH/s`, the single most important number for a miner, shown everywhere.
- **Per-unit breakeven power price** is shown on every machine. Machines below breakeven flash and can auto-shut off (a player setting).

### 7.2 Hardware

Fictional product names, real-world performance as calibration targets. Exact specs, ship dates, launch prices and sources live in `data/hardware/hardware.json` (checked in M1).

| Tier | Era | Example unit (fictional name TBD) | Hashrate | Power | Notes |
|---|---|---|---|---|---|
| CPU | 2009-2010 | Laptop, then home desktop | ~0.8 MH/s (laptop), ~1.6 MH/s (desktop) | ~35 W (laptop), ~105 W (desktop) | The laptop you start with. The whole network ran at ~5 MH/s in 2009. Bitcoin 0.3.6 (July 2010) makes CPU mining 2.4x faster. Later SSE2 and standalone miners helped AMD chips but not the Core 2 class. |
| GPU | 2010-2012 | Open-frame GPU rig | ~340 MH/s per card | ~190 W per card, plus rig overhead | First big jump. Arrives with the first public GPU miner (Oct 2010). |
| FPGA | 2012 | Dev-board cluster | ~800 MH/s | ~40 W | Efficient but expensive, a trap or a niche |
| ASIC Gen 1 | 2013 | First-gen ASIC box | ~66 GH/s | ~620 W | Makes GPUs obsolete overnight |
| ASIC Gen 2 | 2014-2015 | Second-gen | ~1.2 TH/s | ~590 W | ~510 J/TH |
| ASIC Gen 2b | 2015-2016 | Second-gen refresh | ~4.9 TH/s | ~1,210 W | ~250 J/TH, a 2x jump in a year |
| ASIC Gen 3 | 2016-2019 | The workhorse | ~14 TH/s (rated) | ~1,375 W | ~100 J/TH, lasts for years. Some first-batch units ran at 12-13.5 TH/s. |
| ASIC Gen 3b | 2019-2020 | Third-gen refresh | ~53 TH/s | ~2,100 W | ~40 J/TH |
| ASIC Gen 4 | 2020-2022 | Modern | ~110 TH/s | ~3,250 W | ~30 J/TH |
| ASIC Gen 5 | 2022-2024 | Current | ~140 TH/s | ~3,000 W | ~21.5 J/TH |
| ASIC Gen 5b | 2024 | Latest | ~200 TH/s | ~3,500 W | ~17.5 J/TH. ~15 J/TH arrives after the 2024 halving (Act 5). |
| Future | 2024+ | Procedural | Efficiency curve flattening toward physical limits | | |

- **New vs. used market:** used prices track hashprice. In a bear market, used rigs sell for a fraction of new. Fire sales are an opportunity.
- **Lead times** for new ASICs in later acts (pre-orders paid months ahead, shipped into whatever market exists when they arrive).
- **Depreciation:** straight-line over 3 years in the books. Market value is shown alongside book value.

### 7.3 Sites, power and regions

| Site | Act | Capacity | Notes |
|---|---|---|---|
| Bedroom | 1 | ~1 kW | Household power rate, heat makes the room unlivable |
| Garage | 1-2 | ~10 kW | Noise complaints event |
| Warehouse (leased) | 2-3 | ~500 kW | Rent plus a commercial power contract |
| Owned facility | 3-4 | 5-100 MW | Capex heavy, cheapest power |
| Hosted capacity | 3-4 | Variable | Pay a host per kWh, no capex, counterparty risk |

- **Power contracts:** fixed-price (predictable, can be expensive) versus spot (cheap on average, spikes). Curtailment and demand-response revenue in grid-connected regions.
- **Regions (Act 3+):** each has a power price, climate (cooling cost, PUE), seasonality and political risk. Example set: US Texas, US Pacific Northwest, Nordics, China (cheap seasonal hydro, high political risk), Kazakhstan, Canada. The 2021 China ban forces relocation of China sites.
- **Heat and cooling:** capacity is capped by both power (kW) and cooling. Poor cooling lowers uptime.

### 7.4 Network and difficulty

- World hashrate from historical data in Acts 1-4, simulated in Act 5.
- Difficulty retargets every 2,016 blocks. Historical difficulty comes from data; the effective difficulty readout applies the real rule's proportionality, 4x clamp and minimum of 1 to the player's added hashrate (section 7.1).
- The **network share** readout is always visible. It is how the player feels competition.

### 7.5 Market and price

- **Acts 1-4:** historical daily BTC price. No market exists until late 2009, and selling is illiquid until mid-2010. The sell button is disabled with a tooltip: "No market exists yet."
- **Act 5:** procedural price model (see section 9).
- **Fog of time:** charts only ever show the past. Bitcoiners will know what's coming in history mode, and that's fine. The challenge is operational (difficulty growth eating your margin, cash flow timing), not price prediction.

### 7.6 Treasury and custody

Two buckets for BTC:

| | Exchange | Cold storage |
|---|---|---|
| Sell speed | Instant, up to a share of that day's real exchange volume, with slippage | Transfer to exchange first (1 game day) |
| Risk | Counterparty: lost in an exchange failure | Safe |

- Exchange failures are historical events (Mt. Gox 2014, Bitfinex hack 2016 with a socialized haircut, FTX 2022). Coins on the failed exchange are lost or cut.
- Lesson delivered by play, not by lecture: **not your keys, not your coins.**
- **Treasury policy** setting: sell X% of production daily, sell only to cover costs, or HODL everything.
- **Pizza Day (May 22, 2010):** a factual news headline. In Cypherpunk mode, a player holding the coins gets the optional offer of two pizzas for 10,000 BTC. In every mode, once the player mines, forum trade offers (goods for BTC at that day's price) appear, and a "pizza regret" counter tracks the USD value of whatever was spent for the rest of the game.

### 7.7 Finance

| Instrument | Act | Mechanic |
|---|---|---|
| Day job salary | 1 | Fixed monthly income that pays the power bill. Quitting is the Act 1 goal. |
| Personal savings | 1 | Starting cash. No debt allowed before incorporation. |
| Small business loan | 2 | Fixed payments, personal guarantee |
| Equipment financing | 3 | Rigs as collateral, repossession on default |
| Private equity raise | 3 | Cash for ownership % |
| Futures hedge | 3 | Lock a price for part of future production |
| IPO | 4 | Big cash raise, dilution, quarterly earnings pressure events |
| Convertible notes | 4 | Cheap debt that dilutes later |
| BTC-backed loans | 4 | LTV covenant. Price drop → margin call → forced sale if uncured. |

- **Covenants:** minimum liquidity and maximum LTV. A breach starts a cure clock (auto-pause).
- **Score is owner's equity × your ownership %**, so dilution and restructuring are real costs.

### 7.8 Restructuring (Chapter 11)

- **Before incorporation (Act 1):** you cannot go negative. If you cannot pay power, machines shut off. Unpaid living costs are a missed payment.
- **Living costs are personal** in every act: an unpaid share is a missed payment, never company debt.
- **After incorporation:** an unpaid company obligation (power, rent, the loan, repairs) starts a cure clock (auto-pause). If cash still cannot cover it when the clock runs out, or a covenant breach is not cured in time, the company enters Chapter 11.
- **Outcome:** creditors convert debt to equity and your ownership % is cut (scaled to how underwater you are). Some rigs or sites are sold. The company keeps operating.
- **Repeat restructurings** cut ownership again. Below 10% ownership, the board replaces you: the act ends and can be replayed.
- Achievement: "Chapter 11 Speedrun."

### 7.9 Operations (light)

- Uptime, failure rates rising with age and heat, repair costs.
- Technicians in Act 3+ as a simple headcount-to-uptime curve. No staff micromanagement.

### 7.10 Rivals (Act 3+)

Named parody companies with personalities. Their hashrate is carved out of the world total, so they show up in the network share breakdown.

| Archetype | Behavior | Likely fate |
|---|---|---|
| The leveraged expander | Borrows to buy at the top | Bankrupt in 2022, assets auctioned |
| The conservative HODLer | Slow growth, big treasury | Survives, steady |
| The hardware maker turned miner | Mines with its own unsold machines | Volatile |
| The cheap-power specialist | Moves wherever power is cheapest | Hit by the China ban, rebuilds |

- **Auctions:** when a rival fails, its rigs and sites go up for auction. Buying a competitor's machines at a deep discount in a bear market is a signature moment.

### 7.11 Financial statements

- **Act 1-2:** a simple monthly P&L and cash balance.
- **Act 3 (hire a CFO):** unlocks the full balance sheet and cash flow statement, plus the advanced finance instruments.
- **Balance sheet (simplified):** cash, BTC (at fair value), equipment (net of depreciation), sites, debt, equity.
- Optional accounting nods for the Bitcoiner-accountant crowd: impairment-only BTC accounting before the 2023 fair value standard, then a "you can finally mark your BTC to market" event. Off by default if it adds noise.
- Rule: no taxes, no GAAP edge cases unless a scenario calls for it.

## 8. Historical events

Real events appear in news headlines and event cards, stated factually. Counterparties the player transacts with (exchanges, lenders, hosts) use parody names (see open questions). "Replay" means a cinematic chart replay.

| Date | Event | Game effect | Replay |
|---|---|---|---|
| 2009-01-03 | Genesis block | Game start, mentor's first message | |
| 2009-10-05 | First published BTC exchange rate (~$0.00076, set from electricity cost, not a trade) | BTC has a price. Codex: price discovery. | |
| 2010-05-22 | Pizza Day: 10,000 BTC for two pizzas | News; pizza offer in Cypherpunk mode, regret counter | |
| 2010-07-11 | Slashdot covers Bitcoin 0.3, a wave of new users arrives | Mining unlocks (Slashdot mode) | |
| 2010-07 | First major exchange launches | Exchange custody unlocks, selling becomes liquid | |
| 2010-07-29 | Bitcoin 0.3.6: total generating speedup 2.4x | CPU hashrate x2.4 | |
| 2010-08-15 | Value overflow bug creates 184 billion BTC; patched within hours, chain repaired the next day | Brief mining disruption, codex: soft fork | |
| 2010-12 | Pooled mining arrives | Pool option unlocks | |
| 2011-06 | First bubble (~$30) then exchange hack (June 19); crash to ~$2 by November | Price crash | ✓ |
| 2012-11-28 | **Halving 1:** 50 → 25 BTC | End of Act 1 | ✓ |
| 2013-01 | First ASICs ship | ASIC tier unlocks, GPUs start dying | |
| 2013-04 | Spike to ~$230 (~$266 intraday), crash the same week | Volatility | ✓ |
| 2013-10 | Silk Road seized | News, small dip | |
| 2013-11/12 | Rally past $1,000, then China restricts banks | Spike and crash | ✓ |
| 2014-02 | Mt. Gox halts withdrawals and files for bankruptcy | Exchange holdings lost | ✓ |
| 2015-01 | Bear market bottom (~$170) | Hashprice squeeze | ✓ |
| 2016-07-09 | **Halving 2:** 25 → 12.5 BTC | End of Act 2 | ✓ |
| 2016-08 | Bitfinex hack, losses socialized across users (~36% haircut) | Exchange holdings cut | |
| 2017-08 | Bitcoin Cash fork; SegWit activates | Choice: sell or hold the forked coins | |
| 2017-12 | Peak near $20,000; Cboe and CME futures launch | Spike, futures hedging unlocks | ✓ |
| 2018 | Bear market, ~-84% to ~$3,200 | First "boss fight" | ✓ |
| 2020-03-12 | Black Thursday, ~-40% in a day | Margin calls, forced sales | ✓ |
| 2020-05-11 | **Halving 3:** 12.5 → 6.25 BTC | End of Act 3 | ✓ |
| 2020-08 | Public companies start holding BTC as a treasury asset | Investor demand for BTC-heavy balance sheets | |
| 2021-04 | Major exchange lists on Nasdaq; peak ~$64,000 | IPO window opens | ✓ |
| 2021-05/06 | China bans mining; network hashrate roughly halves | Forced relocation, your share jumps | ✓ (hashrate chart) |
| 2021-09-07 | El Salvador makes BTC legal tender | News | |
| 2021-11 | Peak ~$69,000 intraday (~$67,500 close); Taproot activates | Spike | ✓ |
| 2022-05 | Terra/LUNA collapse | Credit tightens | ✓ |
| 2022-06 | Crypto lenders freeze withdrawals | BTC-backed loans recalled | |
| 2022-11 | FTX collapses; BTC ~$15,500 | Exchange holdings lost | ✓ |
| 2022-12 | Large public miner files Chapter 11 | Rival bankruptcy, asset auction | |
| 2023-03 | US bank failures hit crypto-friendly banks | Optional: deposits frozen for days | |
| 2024-01 | US spot Bitcoin ETFs approved | Demand shock | ✓ |
| 2024-03 | New peak ~$73,000 | Spike | ✓ |
| 2024-04-20 | **Halving 4:** 6.25 → 3.125 BTC | End of the historical campaign, Act 5 begins | ✓ |

Prices are UTC daily closes unless marked intraday, because that is what the in-game chart shows. Prices, drawdowns and the 2021 hashrate drop are checked against `data/history/btc_daily.csv` (see `data/history/btc_daily_checks.md`). Each event in `data/events/historical.json` will carry its own source.

## 9. The future (Act 5)

### 9.1 Macro scenarios

At the 2024 halving, one scenario is rolled. At each later halving, the scenario either persists or transitions (starting weights: 70% persist, 30% transition; tunable).

| Scenario | Weight | Price model | Event deck flavor |
|---|---|---|---|
| Hyperbitcoinization | 15% | Strong upward drift, volatility falling over time | Nation-state reserves, sovereign mining |
| Regulatory crackdown | 20% | Choppy, policy shocks | Energy taxes, regional mining bans, licensing |
| Fee market boom | 15% | Moderate drift, fees a large share of revenue | Block space demand, fee spikes |
| Long stagnation | 20% | Low drift, long sideways stretches | Hashprice squeeze, consolidation, M&A |
| Quantum scare | 10% | Confidence crash, recovery if the upgrade lands | Soft-fork debate, signaling choice |
| Grid partner | 20% | Moderate | Demand-response revenue, heat reuse contracts |

Halvings continue on schedule (2028: 3.125 → 1.5625, and so on). As the subsidy shrinks, fees decide who survives.

### 9.2 Player influence (light)

- **Lobbying budget:** reduces the severity of crackdown events in your regions.
- **Grid services investment:** unlocks demand-response revenue, improves regulatory standing.
- **Hashrate share above ~30%:** triggers centralization scrutiny events (regulators, community backlash, pool pressure).
- **Public company status:** activist investor and earnings pressure events.

### 9.3 Price model

- Regime-switching process (bull, bear, crab states as a Markov chain) with lognormal daily returns per regime.
- Jump events (crashes and spikes) drawn from the scenario's event deck.
- Optional halving-cycle bias, tunable. Codex makes the point that the "four-year cycle" is a belief, not a law.
- Seeded RNG. Seeds are shareable ("try seed 21000000").

## 10. Charts and event replays

**Always on:** a price ticker in the top bar showing the current price, 24h %, and a sparkline.

**Market panel:** a full chart with:
- a log/linear toggle (its own teaching moment)
- range presets
- overlays: halvings, your buy and sell markers, hashprice, network hashrate

**Event replay sequence:**
1. Auto-pause and dim the screen.
2. The chart zooms to the event window (30 to 180 days).
3. The line draws itself over 3 to 5 seconds while a drawdown or gain % counter ticks.
4. Annotation pins drop on key days.
5. The event card slides in, with:
   - headline
   - mentor line
   - meme line
   - **What this means for your business**
   - choice buttons, if the event has a decision
6. Resume.

**Replay library:** every replay you've seen can be rewatched from the Codex.

**Pixel style:** charts are drawn at base resolution with 1px lines, no anti-aliasing, and palette colors only.

## 11. Teaching, tone and humor

### 11.1 Teaching rules

- Teach at the moment of need, never front-load.
- Every number has a hover tooltip: definition plus the formula with live values, for example "Hashprice $0.05/TH/day = $1,200 revenue ÷ 24,000 TH/s".
- **Codex:** about 40 entries unlocked on first encounter, for example difficulty adjustment, halving, hashprice, J/TH, PUE, solo vs. pool, custody, forks, margin call, LTV, covenants, depreciation, impairment, fair value, Chapter 11.

### 11.2 The mentor

- An anonymous early cypherpunk, name TBD (placeholder "~anon"). Faceless: a terminal avatar, never a portrait.
- Talks to you through era-appropriate UI: mailing list and forum DMs in 2009-2010. In Slashdot mode the mentor's 2009 posts are the prologue; the mentor then guides you through 2010. No mentor in Late to the party mode.
- Teaches the Act 1 core concepts. Messages thin out through late 2010 and stop in 2011. The nod lands for Bitcoiners without portraying any real person.
- After the mentor goes quiet, teaching shifts to the Codex, tooltips, and the CFO you hire in Act 3, who explains the full statements.

### 11.3 Tone

- Culture humor lives in flavor text, news headlines and achievements. Numbers stay honest.
- **Achievement examples:**
  - Pizza Guy: accept the pizza deal.
  - Diamond Hands: hold through the 2018 bear without selling.
  - Not Your Keys: lose coins in an exchange failure.
  - Have Fun Staying Poor: sell BTC under $1.
  - Laser Eyes: hold through 2022 without restructuring.
  - Chapter 11 Speedrun: restructure in under a year after incorporating.
- **Avoid:** real people's likenesses or portraits, financial advice framing, live crypto of any kind, tokens or NFTs.

## 12. Presentation

### 12.1 Resolution and rendering

- Base resolution 640×360, viewport stretch mode, integer scaling (2x = 1280×720, 3x = 1920×1080).
- Nearest-neighbor filtering, no mipmaps.

### 12.2 Facility view

- Top-down 3/4 perspective on a 16px tile grid. You place machines, coolers and transformers.
- **Site scenes:** bedroom → garage → warehouse → owned facility (containers, then immersion), plus regional exteriors later.

### 12.3 UI layout

- **Top bar:** date, speed controls, price ticker, cash, BTC (exchange and cold), hashrate, network share.
- **Right panel tabs:** Market, Hardware, Sites and Power, Finance, Treasury, Codex.
- **Bottom:** a news ticker.
- **Inbox:** mentor and event messages.
- **Pixel fonts** in two sizes. Text legibility at 1x is a hard requirement.

### 12.4 Art pipeline (PixelLab)

- Lock a style anchor first: one reference sprite plus a 32-color palette.
- Every prompt is logged to `docs/sprite-prompts.md`.
- **MVP asset list:**
  - bedroom and garage tilesets
  - 5 machines (laptop, desktop tower, GPU rig, FPGA board, ASIC box)
  - mentor terminal avatar
  - about 20 UI icons
  - UI frame
  - chart styling

### 12.5 Audio (TBD)

- Chiptune.
- Fan hum that scales with your hashrate.

## 13. Technical architecture

```
res://
  autoload/      game_clock.gd, event_bus.gd, data.gd, save.gd
  sim/           sim_state.gd, mining.gd, power.gd, market.gd, finance.gd,
                 custody.gd, events.gd, rivals.gd, scenarios.gd, price_model.gd, rng.gd
  data/          history/btc_daily.csv, hardware/, events/historical.json,
                 protocol/consensus.json, scenarios/, tuning/*.json
  scenes/        main.tscn, facility/, ui/, charts/
  assets/        sprites/, tiles/, fonts/, audio/, palette
  tests/         unit/, sim/
tools/           data prep scripts (Python)
docs/            GDD.md, decisions.md, art-bible.md, sprite-prompts.md
CLAUDE.md
```

### 13.1 Principles

- **Simulation is pure.** `sim/` classes extend RefCounted, have no Node or scene dependencies, and run headless. One entry point: `Sim.step_day()`.
- **Presentation listens.** UI and facility scenes react to signals on the `EventBus`. They never compute economics.
- **Deterministic.** A seeded RNG lives in `sim/rng.gd`. Same seed plus same inputs gives the same run.
- **No hardcoded tuning.** Every economic and feel value lives in `data/`: protocol facts in `data/protocol/` with sources, judgment calls in `data/tuning/*.json` with a unit, a basis and a note each (validated by `tools/check_tuning.py`). A debug tuning panel (F12) edits values live and dumps them to file.
- **Historical dataset:** daily price, network hashrate, difficulty and average fees per block, 2009 to 2024, prepared once by a script in `tools/` and committed as CSV. Candidate sources include Coin Metrics community data and Blockchain.com charts; confirm licensing before use.
- **Save/load:** JSON serialization of `SimState`.
- **No network calls at runtime.**

## 14. Testing and balance

- **Unit tests:** GUT 9.7.1, vendored in `addons/gut` (decided in M2).
- **Bot runs:** scripted strategies play the whole campaign headless in seconds and write CSV summaries. Expected outcomes act as balance tests in Slashdot mode; the other modes get sanity checks. M2 asserts them over Acts 1-2. Max Leverage's 2018/2022 outcome needs the Act 3-4 finance and is asserted from M6; in M2 it is expected to restructure in the 2014-2015 bear with the one Act 2 loan:

| Bot | Strategy | Must happen | M2 result (Slashdot, Acts 1-2) |
|---|---|---|---|
| Max Leverage | Borrow to the limit, buy every rig | Restructures in 2018 or 2022 | Survives with only the Act 2 loan; fails in Late mode. Asserted from M6 |
| Never Upgrade | Keeps first-gen hardware | Unprofitable by about 2014 | Holds: margin negative from 2014-06 |
| Passive HODLer | Minimal decisions, holds everything | Survives with a low score | Holds: lowest score |
| Hindsight | Knows the future, sells tops | Defines the score ceiling | Holds in every mode |
| Sensible | Rule-based reasonable play | Survives with a good score | Holds: grades A/A |

Latest numbers and findings: `docs/reports/m2-bot-results.md`. The 2009 stack: `docs/reports/laptop-whale.md`.

- **Golden test:** the sim's historical hashprice matches real-world hashprice within a tolerance. With no player hashrate, the anchored chain reproduces history's difficulty every day and the dataset's hashprice within 0.1% on 30-day means, and matches 8 published figures from 2020 to 2024 (Luxor / Hashrate Index, The Block; `data/history/hashprice_references.csv`) within 15%. All 8 land within 10%.

## 15. Scope

### 15.1 Proof-of-fun MVP (M3)

**In scope:**
- Acts 1 and 2 (2009 to 2016)
- Bedroom and garage
- 5 hardware tiers (CPU, GPU, FPGA, ASIC Gen 1-2)
- Solo and pool mining
- Day job
- Sell/hold and exchange vs. cold custody
- One loan
- P&L plus cash
- Price ticker and 4 replays: Pizza Day, the 2011 crash, the 2013 double bubble, Mt. Gox
- Mentor Act 1 script
- About 10 Codex entries

**Not in scope:** all art. It's greybox with placeholder rectangles.

**Success test:**
- A 30-minute session where you want to keep playing.
- At least 1 meaningful decision per 2 real minutes.

### 15.2 Cut until after the vertical slice

- Rivals
- Regions
- IPO
- Hedging
- Technicians
- Audio
- Sandbox mode
- Act 5

## 16. Milestones

| # | Milestone | Output | Gate |
|---|---|---|---|
| M0 | Pitch | This GDD, `CLAUDE.md`, repo scaffold | Decisions locked |
| M1 | Data | Historical CSV 2009-2024, verified event list, hardware data | Data spot-checked against sources |
| M2 | Headless sim | Mining, power, cash, day job, sell/hold, custody, halvings, bots | Bot outcomes match expectations |
| M3 | Greybox | Playable Acts 1-2 with placeholder art, ticker, 4 replays | Proof-of-fun test passes |
| M4 | Style lock | Palette, resolution, 2 tilesets, 5 machines, avatar, UI frame | Assets look like one game |
| M5 | Vertical slice | Acts 1-2 fully arted, mentor, Codex | Representative of final quality |
| M6 | Acts 3-4 | Regions, rivals, CFO, finance instruments, restructuring | Full campaign playable |
| M7 | Future | Scenarios, procedural price, influence | Act 5 replayable |
| M8 | Ship | Polish, itch.io page | Released |

## 17. Risks

| Risk | Mitigation |
|---|---|
| Passive play (watching numbers tick) | Decision density target, hardware obsolescence forcing reinvestment, auto-paused events |
| Spreadsheet creep | Pillar 3; every new number needs a decision attached |
| Known history makes the campaign solved | The challenge is operational, plus objectives beyond profit; sandbox mode later |
| Scope creep | MVP and cut list above; nothing from the cut list before M5 |
| Data licensing | Confirm source license in M1; fallback is a derived, smoothed dataset |
| Real names and likenesses | Parody names for counterparties, no real people depicted |

## 18. Open questions

1. **Title.** Candidates: Proof of Work, Hashpower, Block Reward, Difficulty Adjustment, Stack & Hash.
2. **Mentor handle.**
3. **Historical cutoff.** Lean: April 2024 halving, so acts stay aligned with halvings. Alternative: extend through 2025.
4. **Exchange names.** Lean: parody names for anything you transact with, real names only in historical news.
5. **Perspective.** Lean: top-down 3/4. Alternative: isometric.
6. **Test framework.** Resolved: GUT (decisions.md, 2026-10-16).
7. **PixelLab plan.** Monthly API credit budget.
