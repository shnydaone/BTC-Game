class_name Fmt
extends RefCounted
## Number formatting for readouts and the UI. Pure string work, no economics.

const HASH_UNITS: PackedStringArray = ["H/s", "kH/s", "MH/s", "GH/s", "TH/s", "PH/s", "EH/s"]
const THOUSAND: float = 1000.0


## 1234567 -> "1,234,567". Works on the integer part only.
static func thousands(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	for i: int in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if n < 0 else "") + out


## Cents to dollars: "$1,234" (or "$12.34" under $100), "$1.23M" and "$1.23B" when large.
static func usd(cents: int) -> String:
	var dollars: float = cents / 100.0
	var sign: String = "-" if dollars < 0.0 else ""
	var a: float = absf(dollars)
	if a >= 1.0e9:
		return "%s$%.2fB" % [sign, a / 1.0e9]
	if a >= 1.0e6:
		return "%s$%.2fM" % [sign, a / 1.0e6]
	if a < 100.0:
		return "%s$%.2f" % [sign, a]
	return "%s$%s" % [sign, thousands(roundi(a))]


## A BTC price: enough decimals to show fractions of a cent in 2009-2010.
static func price(usd_value: float) -> String:
	if is_nan(usd_value):
		return "no price"
	if usd_value >= 1000.0:
		return "$" + thousands(roundi(usd_value))
	if usd_value >= 1.0:
		return "$%.2f" % usd_value
	if usd_value >= 0.01:
		return "$%.3f" % usd_value
	return "$%.5f" % usd_value


## Sats to BTC: 8 decimals for small amounts, fewer as the stack grows.
static func btc(sats: int) -> String:
	var v: float = sats / 1.0e8
	if sats == 0:
		return "0"
	if absf(v) >= 1000.0:
		return thousands(roundi(v))
	if absf(v) >= 1.0:
		return "%.2f" % v
	return "%.8f" % v


static func hashrate(hs: float) -> String:
	var v: float = hs
	var unit: int = 0
	while absf(v) >= THOUSAND and unit < HASH_UNITS.size() - 1:
		v /= THOUSAND
		unit += 1
	return ("%.0f %s" if v >= 100.0 else "%.1f %s") % [v, HASH_UNITS[unit]]


static func percent(fraction: float, decimals: int = 1) -> String:
	if is_nan(fraction):
		return "n/a"
	return ("%." + str(decimals) + "f%%") % (fraction * 100.0)


static func signed_percent(fraction: float) -> String:
	if is_nan(fraction):
		return "n/a"
	return ("+" if fraction >= 0.0 else "") + percent(fraction)


static func watts(w: float) -> String:
	if absf(w) >= THOUSAND:
		return "%.1f kW" % (w / THOUSAND)
	return "%d W" % roundi(w)
