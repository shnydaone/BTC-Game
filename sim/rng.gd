class_name SimRng
extends RefCounted
## Seeded randomness for the sim. All randomness in sim/ goes through here.
##
## Each system draws from its own named stream, seeded from the master seed and the
## stream name, so adding a stream or a draw in one system never shifts another.

# FNV-1a, 32-bit. Stable across platforms and Godot versions, unlike String.hash().
const FNV_OFFSET_A: int = 2166136261
const FNV_OFFSET_B: int = 84696351
const FNV_PRIME: int = 16777619
const MASK_32: int = 0xFFFFFFFF
# Knuth's method below this mean, PTRS (Hormann 1993) at or above it.
const POISSON_PTRS_MIN_LAMBDA: float = 30.0

var master_seed: int
var _streams: Dictionary = {}  # String -> RandomNumberGenerator


func _init(seed_value: int) -> void:
	master_seed = seed_value


static func stream_seed(seed_value: int, stream_name: String) -> int:
	var bytes: PackedByteArray = ("%d:%s" % [seed_value, stream_name]).to_utf8_buffer()
	return (_fnv1a(bytes, FNV_OFFSET_A) << 31) ^ _fnv1a(bytes, FNV_OFFSET_B)


static func _fnv1a(bytes: PackedByteArray, offset: int) -> int:
	var h: int = offset
	for b: int in bytes:
		h = ((h ^ b) * FNV_PRIME) & MASK_32
	return h


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = stream_seed(master_seed, stream_name)
		_streams[stream_name] = rng
	return _streams[stream_name]


func uniform(stream_name: String) -> float:
	return stream(stream_name).randf()


func poisson(stream_name: String, lambda: float) -> int:
	if lambda <= 0.0:
		return 0
	var rng := stream(stream_name)
	if lambda < POISSON_PTRS_MIN_LAMBDA:
		return _poisson_knuth(rng, lambda)
	return _poisson_ptrs(rng, lambda)


static func _poisson_knuth(rng: RandomNumberGenerator, lambda: float) -> int:
	var limit: float = exp(-lambda)
	var k: int = 0
	var p: float = rng.randf()
	while p > limit:
		k += 1
		p *= rng.randf()
	return k


static func _poisson_ptrs(rng: RandomNumberGenerator, lambda: float) -> int:
	# Transformed rejection with squeeze, Hormann (1993), "The transformed rejection method
	# for generating Poisson random variables". The constants are part of the algorithm.
	var slam: float = sqrt(lambda)
	var loglam: float = log(lambda)
	var b: float = 0.931 + 2.53 * slam
	var a: float = -0.059 + 0.02483 * b
	var invalpha: float = 1.1239 + 1.1328 / (b - 3.4)
	var vr: float = 0.9277 - 3.6224 / (b - 2.0)
	while true:
		var u: float = rng.randf() - 0.5
		var v: float = rng.randf()
		var us: float = 0.5 - absf(u)
		var k: int = floori((2.0 * a / us + b) * u + lambda + 0.43)
		if us >= 0.07 and v <= vr:
			return k
		if k < 0 or (us < 0.013 and v > us):
			continue
		if log(v) + log(invalpha) - log(a / (us * us) + b) <= -lambda + k * loglam - log_factorial(k):
			return k
	return 0


static func log_factorial(n: int) -> float:
	if n < 2:
		return 0.0
	if n < 16:
		var total: float = 0.0
		for i: int in range(2, n + 1):
			total += log(float(i))
		return total
	# Stirling series for ln(n!), accurate to better than 1e-10 for n >= 16.
	var x: float = float(n)
	return x * log(x) - x + 0.5 * log(TAU * x) + 1.0 / (12.0 * x) - 1.0 / (360.0 * x * x * x)


## RNG positions as strings: the state is a 64-bit unsigned value and JSON numbers are doubles.
func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for stream_name: String in _streams:
		states[stream_name] = str((_streams[stream_name] as RandomNumberGenerator).state)
	return {"master_seed": str(master_seed), "streams": states}


static func from_dict(d: Dictionary) -> SimRng:
	var rng := SimRng.new(String(d["master_seed"]).to_int())
	var states: Dictionary = d["streams"]
	for stream_name: String in states:
		rng.stream(stream_name).state = String(states[stream_name]).to_int()
	return rng
