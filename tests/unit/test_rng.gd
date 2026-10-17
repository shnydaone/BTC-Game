extends GutTest

const DRAWS: int = 20000


func test_stream_seed_matches_reference_values() -> void:
	# Computed independently in Python; guards against platform or version drift.
	assert_eq(SimRng.stream_seed(42, "mining"), 2025765485163021093)
	assert_eq(SimRng.stream_seed(21000000, "hardware"), 461707691719181200)
	assert_eq(SimRng.stream_seed(-7, "x"), 3558998275171125385)


func test_same_seed_gives_same_sequence() -> void:
	var a := SimRng.new(7)
	var b := SimRng.new(7)
	for i: int in 100:
		assert_eq(a.uniform("mining"), b.uniform("mining"))


func test_streams_are_independent() -> void:
	var a := SimRng.new(7)
	var b := SimRng.new(7)
	for i: int in 50:
		b.uniform("hardware")  # extra draws on another stream
	for i: int in 100:
		assert_eq(a.uniform("mining"), b.uniform("mining"))


func test_different_streams_differ() -> void:
	var r := SimRng.new(7)
	assert_ne(r.uniform("mining"), r.uniform("hardware"))


func test_poisson_zero_mean_is_zero() -> void:
	assert_eq(SimRng.new(1).poisson("p", 0.0), 0)


func test_poisson_mean_and_variance() -> void:
	for lambda: float in [0.5, 5.0, 29.0, 30.0, 144.0, 5000.0]:
		var r := SimRng.new(99)
		var total: float = 0.0
		var squares: float = 0.0
		for i: int in DRAWS:
			var k: float = r.poisson("p", lambda)
			total += k
			squares += k * k
		var mean: float = total / DRAWS
		var variance: float = squares / DRAWS - mean * mean
		# Standard error of the mean is sqrt(lambda / DRAWS); allow 5 of them.
		assert_almost_eq(mean, lambda, 5.0 * sqrt(lambda / DRAWS), "mean at lambda %s" % lambda)
		assert_almost_eq(variance / lambda, 1.0, 0.05, "variance at lambda %s" % lambda)


func test_log_factorial() -> void:
	assert_almost_eq(SimRng.log_factorial(10), log(3628800.0), 1e-9)
	var exact: float = 0.0
	for i: int in range(2, 101):
		exact += log(float(i))
	assert_almost_eq(SimRng.log_factorial(100), exact, 1e-9)


func test_state_round_trips_through_json() -> void:
	var a := SimRng.new(123456789)
	for i: int in 37:
		a.uniform("mining")
	a.poisson("blocks", 50.0)
	var b := SimRng.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	for i: int in 20:
		assert_eq(a.uniform("mining"), b.uniform("mining"))
		assert_eq(a.poisson("blocks", 50.0), b.poisson("blocks", 50.0))
