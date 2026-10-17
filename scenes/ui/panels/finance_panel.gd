class_name FinancePanel
extends SidePanel
## Cash, the day job, the company and its loan, and the monthly P&L (GDD 7.7, 7.11).


func build(sim: Sim) -> void:
	var f: Dictionary = Readouts.finance(sim)
	if f["overdue_until"] != "":
		note("A company payment is overdue. Raise cash by %s or the company enters Chapter 11." % f["overdue_until"], UiTheme.DOWN)
	section("POSITION")
	row("Cash", Fmt.usd(Readouts.cash_cents(sim)), Readouts.cash_tooltip(sim))
	row("Equity", Fmt.usd(f["equity_cents"]), "Cash + BTC at the last close + machines at book - debt.")
	row("Ownership", Fmt.percent(f["ownership"], 1), "Your share of the company. Chapter 11 cuts it; below 10% the board replaces you.")
	row("Score", Fmt.usd(f["score_cents"]), "Equity x ownership.")
	if int(f["missed_cents"]) > 0:
		row("Missed payments", Fmt.usd(f["missed_cents"]), "Personal bills you could not pay.", UiTheme.DOWN)

	section("DAY JOB")
	if f["objective_met_on"] != "":
		row("Quit-your-job goal", "met %s" % f["objective_met_on"], "", UiTheme.UP)
	else:
		row("Quit-your-job goal", "%d / %d days" % [f["objective_streak"], f["objective_needed"]],
			"Days in a row that mining revenue over the last month covered a month of living costs.")
	row("Salary", "%s/month" % Fmt.usd(f["salary_cents"]) if bool(f["employed"]) else "none")
	row("Living costs", "%s/month" % Fmt.usd(f["living_cents"]), "Owed on the 1st, job or no job.")
	if bool(f["employed"]):
		buttons([action("Quit the day job", {"type": "quit_job"}, "Quit your day job? Your salary stops; living costs do not. Getting a job back takes %d days." % sim.finance.rehire_delay_days)])
	elif f["rehire_date"] != "":
		note("New job starts %s." % f["rehire_date"])
	else:
		buttons([action("Look for a job", {"type": "rejoin_job"}, "Start looking for a day job? It takes %d days to land one." % sim.finance.rehire_delay_days)])

	section("COMPANY")
	if bool(f["incorporated"]):
		row("Status", "incorporated")
	elif bool(f["can_incorporate"]):
		buttons([action("Incorporate (%s)" % Fmt.usd(f["incorporation_cents"]), {"type": "incorporate"},
			"Incorporate for %s? A company can borrow and lease a warehouse, and can go through Chapter 11." % Fmt.usd(f["incorporation_cents"]))])
	else:
		note("Incorporation opens in Act 2.")
	if bool(f["loan_taken"]):
		row("Loan balance", Fmt.usd(f["loan_balance_cents"]))
		row("Loan payment", "%s/month" % Fmt.usd(f["loan_payment_cents"]))
	elif bool(f["incorporated"]):
		buttons([action("Take the loan (%s)" % Fmt.usd(f["loan_offer_cents"]), {"type": "take_loan"},
			"Borrow %s at %s a year over %d months? Payments are %s a month." % [Fmt.usd(f["loan_offer_cents"]), Fmt.percent(f["loan_rate"], 0), f["loan_months"], Fmt.usd(f["loan_offer_payment_cents"])])])

	section("THIS MONTH")
	var net: int = 0
	for r: Array in Readouts.this_month(sim):
		row(r[0], Fmt.usd(r[1]), "", UiTheme.UP if int(r[1]) >= 0 else UiTheme.DOWN)
		net += int(r[1])
	row("Net so far", Fmt.usd(net), "Mining revenue is booked at each day's close. Buying and selling BTC moves cash, not profit.")
	var last: Dictionary = Readouts.last_month(sim)
	if not last.is_empty():
		row("Last month (%s)" % last["month"], Fmt.usd(last["net_cents"]), "", UiTheme.UP if int(last["net_cents"]) >= 0 else UiTheme.DOWN)
