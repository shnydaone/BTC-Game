class_name History
extends RefCounted
## The historical daily dataset (data/history/btc_daily.csv), one row per UTC day,
## held in packed arrays and indexed by day number from the first row.

const SECONDS_PER_DAY: int = 86400
const COLUMNS: PackedStringArray = [
	"date", "price_usd", "price_source", "blocks", "height_end", "difficulty",
	"hashrate_hs", "hashrate_hs_7d", "fees_btc", "fees_per_block_btc", "subsidy_btc", "tx_count",
]

var dates: PackedStringArray = []
var price_usd: PackedFloat64Array = []  # NAN before the first published price
var blocks: PackedInt32Array = []
var height_end: PackedInt64Array = []
var difficulty: PackedFloat64Array = []
var hashrate_hs: PackedFloat64Array = []
var fees_btc: PackedFloat64Array = []
var subsidy_btc: PackedFloat64Array = []

var _first_unix_day: int = 0


static func load_csv(path: String) -> History:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("History: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var header: PackedStringArray = f.get_csv_line()
	if header != COLUMNS:
		push_error("History: unexpected columns in %s: %s" % [path, header])
		return null
	var h := History.new()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < COLUMNS.size():
			continue  # trailing blank line
		h.dates.append(row[0])
		h.price_usd.append(row[1].to_float() if row[1] != "" else NAN)
		h.blocks.append(row[3].to_int())
		h.height_end.append(row[4].to_int())
		h.difficulty.append(row[5].to_float())
		h.hashrate_hs.append(row[6].to_float())
		h.fees_btc.append(row[8].to_float())
		h.subsidy_btc.append(row[10].to_float())
	h._first_unix_day = unix_day(h.dates[0])
	if not h._is_contiguous():
		push_error("History: %s is missing days" % path)
		return null
	return h


static func unix_day(iso_date: String) -> int:
	return Time.get_unix_time_from_datetime_string(iso_date) / SECONDS_PER_DAY


static func iso_from_unix_day(day: int) -> String:
	return Time.get_date_string_from_unix_time(day * SECONDS_PER_DAY)


func size() -> int:
	return dates.size()


func first_date() -> String:
	return dates[0]


func last_date() -> String:
	return dates[dates.size() - 1]


## Row index for an ISO date, or -1 outside the dataset.
func index_of(iso_date: String) -> int:
	var i: int = unix_day(iso_date) - _first_unix_day
	return i if i >= 0 and i < dates.size() else -1


func has_price(i: int) -> bool:
	return not is_nan(price_usd[i])


func _is_contiguous() -> bool:
	for i: int in dates.size():
		if unix_day(dates[i]) != _first_unix_day + i:
			return false
	return true
