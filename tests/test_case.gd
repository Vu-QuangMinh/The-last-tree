class_name TestCase
extends RefCounted
## Minimal assertion base for the headless runner. Failures are recorded, not thrown.

var failures: Array[String] = []


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("expected true. " + msg)


func assert_eq(actual, expected, msg := "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		failures.append("expected %s (%s) got %s (%s). %s" % [expected, type_string(typeof(expected)), actual, type_string(typeof(actual)), msg])
	elif actual != expected:
		failures.append("expected %s got %s. %s" % [expected, actual, msg])


func assert_near(actual: float, expected: float, tol := 0.001, msg := "") -> void:
	if absf(actual - expected) > tol:
		failures.append("expected %s ± %s got %s. %s" % [expected, tol, actual, msg])


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
