class_name Ledger
extends RefCounted
## Monthly profit and loss (GDD 7.11, Acts 1-2: a simple P&L plus cash).
##
## Signed cents per category: income positive, expenses negative. Mining revenue is
## booked at the day's close when mined. Buying and selling BTC moves cash, not profit.


static func post(state: SimState, category: String, cents: int) -> void:
	if cents == 0:
		return
	var totals: Dictionary[String, int] = state.ledger.totals
	totals[category] = totals.get(category, 0) + cents


## Closes the month when the date moves into a new one. Call before the day's postings.
static func roll(state: SimState, iso_date: String, result: DayResult) -> void:
	var month: String = iso_date.substr(0, 7)
	var l: SimState.LedgerState = state.ledger
	if l.month == "":
		l.month = month
		return
	if month == l.month:
		return
	var closed := SimState.MonthTotals.new()
	closed.month = l.month
	var net: int = 0
	for category: String in l.totals:
		closed.totals[category] = l.totals[category]
		net += l.totals[category]
	l.history.append(closed)
	result.add("month_closed", {"month": l.month, "net_cents": net})
	l.totals.clear()
	l.month = month


static func month_net(totals: Dictionary[String, int]) -> int:
	var net: int = 0
	for category: String in totals:
		net += totals[category]
	return net
