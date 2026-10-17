# Sources for btc_daily.csv

Built by `tools/build_btc_daily.py`. Dates are UTC. Prices are daily closes in USD.

## Columns

| Column | Meaning |
|---|---|
| date | UTC date |
| price_usd | Daily close in USD. Blank before the first published rate (2009-10-05). |
| price_source | `none`, `anchor` (hand-entered, see `tools/data/price_anchors.csv`), `anchor_interp` (log interpolation between anchors), `mtgox`, `bitstamp`, `ffill` (no trades that day, last close carried) |
| blocks | Blocks with a timestamp on that date |
| height_end | Highest block height seen so far |
| difficulty | Difficulty of the highest block that day (carried on days with no blocks) |
| hashrate_hs | Estimated network hashrate in H/s: sum of block difficulty x 2^32 / 86,400. Hashrate cannot be measured directly; every source estimates it this way. |
| hashrate_hs_7d | Centered 7-day mean of hashrate_hs. Use this for charts; the daily value is noisy. |
| fees_btc | Total transaction fees paid that day |
| fees_per_block_btc | fees_btc / blocks (blank on days with no blocks) |
| subsidy_btc | Total block subsidy that day |
| tx_count | Transactions, including coinbase |

## Sources

| Data | Source | Terms |
|---|---|---|
| Blocks, difficulty, fees, subsidy | Google BigQuery public dataset `bigquery-public-data.crypto_bitcoin`, query in `tools/sql/btc_blocks_daily.sql` | Public blockchain data. No third-party license on the underlying facts. |
| Price 2010-07-18 to 2012-12-31 | Mt. Gox trade prints, bitcoincharts.com archive (Internet Archive snapshot: https://web.archive.org/web/20161229014309id_/http://api.bitcoincharts.com/v1/csv/mtgoxUSD.csv.gz) | **Unknown.** bitcoincharts.com is offline and published no license. Open item for Eric. |
| Price 2013-01-01 to 2024-12-31 | Bitstamp public API, `/api/v2/ohlc/btcusd/` daily candles | Bitstamp allows commercial redistribution of its exchange data and asks commercial users to sign a Data License Agreement (partners@bitstamp.net). |
| Price 2009-10-05 to 2010-07-17 | Hand-entered anchors with sources in `tools/data/price_anchors.csv` | Historical facts, cited per row. |

## Raw files

| File | SHA-256 |
|---|---|
| `tools/raw/bq_blocks_daily.csv` | `802d3d14699122e511fb5a30b0cf424b21f7ae15d025e27db4da40a760c4c885` |
| `tools/raw/mtgoxUSD.csv.gz` | `1a880feeadfe3c535c54aec4e66912fa6f277b3fb14f00829f05a345ab4b91eb` |
| `tools/raw/bitstamp_ohlc_daily.json` | `6c59b34a164b7cc3de830fcc177303acd19a8fa43d85bdfd7f9590acb00475ee` |
