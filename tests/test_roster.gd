extends SceneTree

const Allocation = preload("res://sim/allocation.gd")
const Casting = preload("res://sim/casting.gd")

const BALANCED := { build = 11_000.0, quality = 6_000.0, depth = 5_000.0, marketing = 4_000.0 }
# redundancy pair: identical spend except the build rung, no bench
const FOUR_SCARE := { build = 11_000.0, quality = 6_000.0, depth = 0.0, marketing = 4_000.0 }
const THREE_SCARE := { build = 9_500.0, quality = 6_000.0, depth = 0.0, marketing = 4_000.0 }

const SEED := 12345
const SEEDS := 5
const MIN_RESPONSE_EDGE := 1.20 # honest run measured 1.248x mean
const MIN_REDUNDANCY_GAP := 0.15 # honest run measured 0.203 loss_frac gap

var failed := 0


func _initialize() -> void:
	response_matters()
	redundancy_absorbs()
	print("PASS: roster invariants hold" if failed == 0 else "FAIL: %d broken" % failed)
	quit(1 if failed > 0 else 0)


func response_matters() -> void:
	var re_sum := 0.0
	var never_sum := 0.0
	print("seed  | REASSIGN | NEVER | edge")
	for s in SEEDS:
		var re := final_cash(Allocation.run_season(BALANCED, SEED + s, Casting.REASSIGN))
		var never := final_cash(Allocation.run_season(BALANCED, SEED + s, Casting.NEVER))
		re_sum += re
		never_sum += never
		print("%d | $%.0f | $%.0f | %.2fx" % [SEED + s, re, never, re / never])
	var edge := re_sum / never_sum
	print("mean edge %.3fx" % edge)
	check(
		edge >= MIN_RESPONSE_EDGE,
		"responding to callouts pays only %.2fx (want %.2fx)" % [edge, MIN_RESPONSE_EDGE],
	)


func redundancy_absorbs() -> void:
	var loss4 := mean_loss(FOUR_SCARE, "4-scare")
	var loss3 := mean_loss(THREE_SCARE, "3-scare")
	check(
		loss4 < loss3 - MIN_REDUNDANCY_GAP,
		"redundancy fails to absorb: 4-scare loses %.1f%% vs 3-scare %.1f%%"
		% [loss4 * 100.0, loss3 * 100.0],
	)


func mean_loss(alloc: Dictionary, label: String) -> float:
	var total := 0.0
	for s in SEEDS:
		var baseline := final_cash(Allocation.run_season(alloc, SEED + s, Casting.NEVER, false))
		var live := final_cash(Allocation.run_season(alloc, SEED + s, Casting.NEVER))
		total += 1.0 - live / baseline
	var loss := total / SEEDS
	print("%s mean loss_frac %.3f" % [label, loss])
	return loss


func check(ok: bool, msg: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: " + msg)


static func final_cash(records: Array[Dictionary]) -> float:
	return records[-1].cash
