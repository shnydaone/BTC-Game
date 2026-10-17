class_name Messages
extends RefCounted
## Turns sim events into short player-facing lines for the inbox, news ticker and toasts.
## Greybox wording; the M3-4 content pass rewrites it. Returns {} for events nobody sees.
##
## Kinds: "news" (historical headline), "alert" (needs attention), "info", "toast" (brief).


static func describe(sim: Sim, e: Dictionary) -> Dictionary:
	match e["type"]:
		"historical_event":
			return {"kind": "news", "text": String(e["headline"])}
		"offer_made":
			var what: String = "Two pizzas" if e["kind"] == "pizza" else "A forum trade offer"
			return {"kind": "alert", "text": "%s: goods worth %s for %s BTC. See Treasury." % [what, Fmt.usd(e["value_cents"]), Fmt.btc(e["sats"])]}
		"objective_met":
			return {"kind": "alert", "text": "Goal met: mining now covers your living costs. You can quit the day job."}
		"act_ended":
			return {"kind": "alert", "text": "Act %d ends. Grade %s, score %s." % [int(e["act"]), e["grade"], Fmt.usd(roundi(float(e["score_usd"]) * 100.0))]}
		"exchange_failed":
			return {"kind": "alert", "text": "%s failed. You lost %s BTC." % [Readouts.exchange_label(sim, e["exchange"]), Fmt.btc(e["lost_sats"])]}
		"exchange_selected":
			return {"kind": "info", "text": "Trading on %s." % Readouts.exchange_label(sim, e["exchange"])}
		"wallet_lost":
			return {"kind": "alert", "text": "Your wallet's disk died. %s BTC are gone." % Fmt.btc(e["sats"])}
		"hardware_arrived":
			return {"kind": "toast", "text": "%d %s arrived." % [e["count"], Readouts.unit_label(sim, e["unit_id"])]}
		"hardware_failed":
			return {"kind": "info", "text": "%d %s broke down." % [e["count"], Readouts.unit_label(sim, e["unit_id"])]}
		"hardware_repaired":
			return {"kind": "toast", "text": "Repairs: %d machines for %s." % [e["count"], Fmt.usd(e["cost_cents"])]}
		"hardware_sped_up":
			return {"kind": "info", "text": "New software: %s mining %.1fx faster." % [e["tier"], e["multiplier"]]}
		"machines_shut_off":
			return {"kind": "alert", "text": "Not enough cash for power: %d machines shut off." % e["count"]}
		"block_found":
			return {"kind": "toast", "text": "You found %s! +%s BTC" % ["a block" if int(e["count"]) == 1 else "%d blocks" % e["count"], Fmt.btc(e["sats"])]}
		"difficulty_adjusted":
			return {"kind": "toast", "text": "Difficulty %s" % Fmt.signed_percent(e["change"])}
		"subsidy_halved":
			return {"kind": "news", "text": "Halving: the block reward is now %s BTC." % Fmt.btc(e["subsidy_sats"])}
		"feature_unlocked":
			return {"kind": "info", "text": "Unlocked: %s." % String(e["feature"]).replace("_", " ")}
		"codex_unlocked":
			return {"kind": "info", "text": "Codex: %s." % Readouts.codex_title(e["entry"])}
		"job_resumed":
			return {"kind": "info", "text": "You start a new day job."}
		"loan_repaid":
			return {"kind": "info", "text": "The loan is paid off."}
		"payment_missed":
			return {"kind": "alert", "text": "You could not pay %s of personal bills." % Fmt.usd(e["cents"])}
		"payment_overdue":
			return {"kind": "alert", "text": "A company payment of %s is overdue. Fix it within the cure period or face Chapter 11." % Fmt.usd(e["cents"])}
		"payment_cured":
			return {"kind": "info", "text": "The overdue payment is covered."}
		"restructured":
			return {"kind": "alert", "text": "Chapter 11: creditors cut your ownership to %s." % Fmt.percent(e["ownership"], 1)}
		"act_lost":
			return {"kind": "alert", "text": "The board replaced you. The act is lost."}
		"pizza_milestone":
			return {"kind": "news", "text": "The 10,000 BTC from Pizza Day are now worth %s." % Fmt.usd(e["value_cents"])}
	return {}
