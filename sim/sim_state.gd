class_name SimState
extends RefCounted
## All mutable simulation state, grouped by system. Systems read and write it;
## save/load serializes it through Serial. Money: BTC in integer satoshis, USD in
## integer cents (decisions.md 2026-10-16).

const SCHEMA_VERSION: int = 3

var schema_version: int = SCHEMA_VERSION
var mode_id: String = ""
var day_index: int = 0  # the next day step_day() will simulate
var player_hashrate_hs: float = 0.0  # running fleet hashrate, set by the power system each day
## When zero or more, replaces the fleet hashrate (tests and the debug panel).
var hashrate_override_hs: float = -1.0
var network: NetworkState = NetworkState.new()
var events: EventsState = EventsState.new()
var hardware: HardwareState = HardwareState.new()
var finance: FinanceState = FinanceState.new()
var custody: CustodyState = CustodyState.new()
var market: MarketState = MarketState.new()
var mining: MiningState = MiningState.new()
var offers: OffersState = OffersState.new()
var objectives: ObjectivesState = ObjectivesState.new()
var ledger: LedgerState = LedgerState.new()


class NetworkState:
	extends RefCounted
	## Anchored chain: height and blocks come from history (decisions.md 2026-10-16).
	var height: int = 0  # chain height at the end of the last simulated day
	var blocks_today: int = 0
	var world_hashrate_hs: float = 0.0
	var player_hashrate_hs: float = 0.0
	var network_hashrate_hs: float = 0.0
	var player_share: float = 0.0
	var subsidy_sats_today: int = 0
	var fees_sats_today: int = 0
	var historical_difficulty: float = 1.0
	## What the 2,016-block rule would set against world plus player hashrate. A readout:
	## block counts stay historical, so it does not change rewards.
	var effective_difficulty: float = 1.0
	var epoch_world_hs_sum: float = 0.0
	var epoch_player_hs_sum: float = 0.0
	var epoch_days: int = 0


class EventsState:
	extends RefCounted
	var fired: PackedStringArray = []  # historical event ids, in firing order
	var features: PackedStringArray = []  # unlocked features: mining, selling, pool_mining, ...
	var codex: PackedStringArray = []  # unlocked Codex entries, in unlock order


class Lot:
	extends RefCounted
	## Identical units bought together.
	var id: int = 0
	var unit_id: String = ""
	var count: int = 0
	var broken: int = 0
	var running: int = 0  # units hashing today, decided by the power system
	var powered: bool = true  # the player's on/off switch
	var bought_day: int = 0  # age reference (earlier than the purchase day for used units)
	var purchased_day: int = 0  # depreciation starts here
	var arrive_day: int = 0
	var cost_cents: int = 0  # book cost, including any GPU rig overhead


class HardwareState:
	extends RefCounted
	var lots: Array[Lot] = []
	var next_lot_id: int = 1
	var site_id: String = ""
	var shutoff_unprofitable: bool = false
	var tier_multipliers: Dictionary[String, float] = {}  # from hardware_speedup events
	var power_cents_today: int = 0


class FinanceState:
	extends RefCounted
	var cash_cents: int = 0
	var employed: bool = true
	var rehire_day: int = -1
	var incorporated: bool = false
	var ownership: float = 1.0
	var loan_taken: bool = false
	var loan_balance_cents: int = 0
	var loan_payment_cents: int = 0
	var missed_cents: int = 0  # personal payments that could not be made
	var personal_cents_today: int = 0  # living costs charged today (personal, never a company debt)
	var overdue_since_day: int = -1  # first day the company was short; starts the cure clock


class Transfer:
	extends RefCounted
	var sats: int = 0
	var origin: String = ""  # "cold" or an exchange id
	var destination: String = ""
	var arrive_day: int = 0


class CustodyState:
	extends RefCounted
	var cold_sats: int = 0
	var exchange_sats: Dictionary[String, int] = {}
	var transfers: Array[Transfer] = []
	var closed_exchanges: PackedStringArray = []
	var active_exchange: String = ""
	var backed_up: bool = false


class Trade:
	extends RefCounted
	## The player's BTC trades on one day and side, for chart markers.
	var day: int = 0
	var side: String = ""  # buy or sell
	var sats: int = 0
	var cents: int = 0


class MarketState:
	extends RefCounted
	var sold_today_sats: int = 0
	var bought_today_sats: int = 0
	var policy: String = "hodl"  # hodl, sell_percent, cover_costs
	var sell_percent: float = 0.0
	var trades: Array[Trade] = []  # one entry per day and side


class MiningState:
	extends RefCounted
	var mode: String = "solo"
	var remainder_sats: float = 0.0  # fractional pool payout carried to the next day
	var mined_sats_today: int = 0
	var mined_value_cents_today: int = 0
	var blocks_found: int = 0


class Offer:
	extends RefCounted
	var id: int = 0
	var kind: String = "forum"  # forum or pizza
	var sats: int = 0
	var value_cents: int = 0
	var expires_day: int = 0


class OffersState:
	extends RefCounted
	var open: Array[Offer] = []
	var next_id: int = 1
	var next_offer_day: int = -1
	var spent_sats: int = 0  # the regret counter's base: BTC spent on goods
	var decided: int = 0  # offers the player accepted or declined


class ObjectivesState:
	extends RefCounted
	var act: int = 1
	var revenue_window: PackedInt64Array = []  # mined value per day, cents, newest last
	var streak: int = 0
	var quit_job_met_on: String = ""
	var crash_sold: bool = false
	var crash_held_sats: int = 0
	var exchange_losses_sats: int = 0  # this act
	var act_peak_hashrate_hs: float = 0.0  # highest running hashrate this act
	var restructurings: int = 0  # whole game
	var act_lost: bool = false
	var report_cards: Array[Dictionary] = []  # floats and strings only (see Serial)


class MonthTotals:
	extends RefCounted
	var month: String = ""
	var totals: Dictionary[String, int] = {}


class LedgerState:
	extends RefCounted
	## Profit and loss by month. Signed cents: income positive, expenses negative.
	var month: String = ""
	var totals: Dictionary[String, int] = {}
	var history: Array[MonthTotals] = []


func to_dict() -> Dictionary:
	return Serial.to_dict(self)


static func from_dict(d: Dictionary) -> SimState:
	if int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("SimState: save schema %s, expected %d" % [d.get("schema_version"), SCHEMA_VERSION])
		return null
	var s := SimState.new()
	Serial.from_dict(s, d)
	return s
