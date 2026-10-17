-- Daily Bitcoin block aggregates by UTC date, 2009-01-03 to 2024-12-31.
--
-- Run in the BigQuery console (https://console.cloud.google.com/bigquery),
-- then Save results > CSV (local file) to tools/raw/bq_blocks_daily.csv.
-- About 5,840 rows. Scans roughly 50 GB, inside the 1 TB monthly free tier.
--
-- Columns:
--   date              UTC date of the block timestamp
--   blocks            blocks with a timestamp on that date
--   height_min/max    lowest and highest block height on that date
--   bits_last         compact difficulty target of the highest block that day
--   difficulty_sum    sum of per-block difficulty (expected hashes = difficulty * 2^32)
--   tx_count          transactions, including coinbase
--   fees_sat          sum of non-coinbase transaction fees, in satoshis
--   subsidy_sat       sum of the protocol block subsidy, in satoshis
--   coinbase_out_sat  sum of coinbase outputs (subsidy + fees actually claimed)

WITH blocks AS (
  SELECT
    number AS height,
    DATE(timestamp) AS day,
    bits,
    transaction_count,
    (65535 / CAST(CONCAT('0x', SUBSTR(bits, 3)) AS INT64))
      * POW(256, 29 - CAST(CONCAT('0x', SUBSTR(bits, 1, 2)) AS INT64)) AS difficulty,
    5000000000 >> DIV(number, 210000) AS subsidy_sat
  FROM `bigquery-public-data.crypto_bitcoin.blocks`
  WHERE timestamp_month <= DATE '2025-01-01'
),
tx AS (
  SELECT
    block_number AS height,
    SUM(IF(is_coinbase, 0, fee)) AS fees_sat,
    SUM(IF(is_coinbase, output_value, 0)) AS coinbase_out_sat
  FROM `bigquery-public-data.crypto_bitcoin.transactions`
  WHERE block_timestamp_month <= DATE '2025-01-01'
  GROUP BY block_number
)
SELECT
  b.day AS date,
  COUNT(*) AS blocks,
  MIN(b.height) AS height_min,
  MAX(b.height) AS height_max,
  ARRAY_AGG(b.bits ORDER BY b.height DESC LIMIT 1)[OFFSET(0)] AS bits_last,
  SUM(b.difficulty) AS difficulty_sum,
  SUM(b.transaction_count) AS tx_count,
  SUM(COALESCE(t.fees_sat, 0)) AS fees_sat,
  SUM(b.subsidy_sat) AS subsidy_sat,
  SUM(COALESCE(t.coinbase_out_sat, 0)) AS coinbase_out_sat
FROM blocks AS b
LEFT JOIN tx AS t USING (height)
WHERE b.day <= DATE '2024-12-31'
GROUP BY date
ORDER BY date
