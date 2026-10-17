# M2 bot results

Bots play Acts 1-2 headless (2009 or 2012 to the halving on 2016-07-09) through `Sim.apply()`, the same commands the UI will use. Score is owner's equity times ownership on Act 2's report card. Seeds 1 to 3; scores barely move between seeds because solo luck only matters before pools arrive in December 2010. Reproduce with:

```
godot --headless --path . --script res://tests/sim/run_bots.gd -- --seeds 3
```

Tuning values are the proposals from M2 PR 2. All numbers below come from that run.

## Slashdot mode (the default campaign, where GDD 14's expectations are asserted)

| Bot | Score at Act 2 end | Grades (Act 1/2) | Outcome | GDD 14 expectation | Status |
|---|---|---|---|---|---|
| Hindsight | $371M to $376M | B/A | Survived, 579,594 BTC | Defines the score ceiling | Holds on every seed |
| Sensible | $104M to $107M | A/A | Survived, quit the day job on 2011-01-21, 140,276 BTC | Survives with a good score | Holds |
| Never Upgrade | $4.3M | C/C | Fleet margin negative for 60 days from 2014-06-11 | Unprofitable by about 2014 | Holds |
| Max Leverage | $0.94M to $1.0M | C/A | Survived, borrowed and filled the warehouse | Interim: restructures in the 2014-2015 bear | **Does not hold** (see below) |
| Passive HODLer | $0.26M to $0.39M | C/C | Survived, 250 BTC | Survives with a low score | Holds (lowest of the five) |

## Other modes (sanity checks only)

| Bot | Cypherpunk | Late to the party |
|---|---|---|
| Hindsight | $974M to $978M | $31.9M |
| Max Leverage | $959M to $964M | Restructured 5 times in early 2016, act lost |
| Sensible | $180M to $183M | $73,608 |
| Passive HODLer | $96M to $100M | $48,934 |
| Never Upgrade | $91M to $95M | $35,840 |

## Findings for Eric

1. **Max Leverage survives Acts 1-2 in Slashdot mode.** It buys the first ASICs in early 2013, when payback was about a week, fills a 500 kW warehouse and banks about $2M in cash. The one $50,000 Act 2 loan cannot threaten that. Leverage does bite in Late mode, which starts in the ASIC era with no GPU-era cushion. The GDD's 2018/2022 outcome needs the Act 3-4 debt (equipment financing, BTC-backed loans), so the test stays pending until M6 (decided 2026-10-17), not retuned.
2. **The Act 2 warehouse stays (decided 2026-10-17).** GDD 6 lists a warehouse as an Act 2 unlock. Without it, leverage cannot grow past a 10 kW garage. It sits in `data/tuning/sites.json` (500 kW, $0.10/kWh, $3,000 a month, needs incorporation).
3. **Slashdot mode still makes GPU-era whales.** Sensible ends Act 1 with about 117,000 BTC mined by a garage of GPU cards in 2010-2011. Each card makes about 11,000 BTC over Q4 2010 to 2011, and the garage holds about 44. That is honest history, and it is earned with a purchase decision. But scores in the hundreds of millions mean the Act 2 cash constraint barely binds for a sensible player.
4. **The liquidity cap barely touches the whale at the 2011 peak.** Mt. Gox traded about 105,000 BTC on 2011-06-08, so even the 153,650-BTC laptop stack sells out in about 15 days at the 10% cap (see `laptop-whale.md`). The cap bites in 2010 and from 2013, when this dataset's volume is Bitstamp's alone.
5. **Hindsight needed a real oracle to be the ceiling.** A one-year lookahead sold the 2011 top, and cautious hardware rules skipped 2009 desktops. It now values coins at the best close still to come, sells only ahead of a 50% drop, and buys back before the next rally. In Cypherpunk it beats Max Leverage by about 1.4%, because both win by buying 2009 hashrate when it was cheapest.
