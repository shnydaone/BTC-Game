class_name SitesPanel
extends SidePanel
## Where the machines run: this site's power, and the sites you could move to.


func build(sim: Sim) -> void:
	section("THIS SITE")
	var here: String = Readouts.site_name(sim)
	for s: Dictionary in Readouts.sites(sim):
		if s["id"] != here:
			continue
		row("Site", here.capitalize())
		row("Power in use", "%s / %s" % [Fmt.watts(Readouts.running_w(sim)), Fmt.watts(s["capacity_w"])], Readouts.power_tooltip(sim))
		row("Power price", "%s/kWh" % Fmt.price(s["usd_per_kwh"]))
		row("PUE", "%.2f" % s["pue"], "Power usage effectiveness: every 1 kWh of machines costs %.2f kWh with cooling." % s["pue"])
		row("Rent", "%s/month" % Fmt.usd(s["rent_cents"]))
		row("Power bill today", Fmt.usd(sim.state.hardware.power_cents_today),
			"Sum of running machines: watts x uptime x 24 h / 1000 x %s/kWh x PUE %.2f" % [Fmt.price(s["usd_per_kwh"]), s["pue"]])
	section("OTHER SITES")
	for s: Dictionary in Readouts.sites(sim):
		if s["id"] == here:
			continue
		row(String(s["id"]).capitalize(), "%s, %s/kWh" % [Fmt.watts(s["capacity_w"]), Fmt.price(s["usd_per_kwh"])])
		row("  Rent / move", "%s/mo, %s" % [Fmt.usd(s["rent_cents"]), Fmt.usd(s["move_cents"])])
		if s["blocked"] != "":
			note(String(s["blocked"]).capitalize() + ".")
		else:
			buttons([action("Move here", {"type": "move_site", "site_id": s["id"]},
				"Move to the %s for %s? Rent becomes %s a month." % [s["id"], Fmt.usd(s["move_cents"]), Fmt.usd(s["rent_cents"])])])
