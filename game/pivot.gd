extends Control

const Allocation = preload("res://sim/allocation.gd")
const Night = preload("res://sim/night.gd")
const Town = preload(("res://sim/town.gd"))

const STEP := 500.0
const MARKETING_CAP := floorf(
	(Allocation.MAX_STARTING_REP - Town.STARTING_REP) * Allocation.DOLLARS_PER_REP / STEP
) * STEP # $11,000: last step before rep pins at 78

const KNOBS := [
	{ key = "build", label = "Build" },
	{ key = "quality", label = "Casting budget" },
	{ key = "depth", label = "Cast depth" },
	{ key = "marketing", label = "Marketing" },
]

const SKILL_WORDS := [[4.0, "green"], [7.0, "solid"], [9.0, "strong"], [999.0, "headliner"]]

var sliders := { }
var effects := { }


func _ready() -> void:
	%Description.text = (
		"Build your haunt, survive October, make the most money by Halloween. Don't let the bank call your loan at %s.\n"
		% money(Night.LOAN_LIMIT)
		+ "Pre-season: split your budget."
	)
	_build_rows()
	%RunButton.pressed.connect(_on_run)
	%StartButton.pressed.connect(_on_start_october)
	if not GameState.alloc.is_empty():
		sliders["build"].value = rung_index(GameState.alloc.build)
		sliders["quality"].value = GameState.alloc.quality
		sliders["depth"].value = GameState.alloc.depth / Allocation.SPARE_COST
		sliders["marketing"].value = GameState.alloc.marketing
	_refresh()


func _build_rows() -> void:
	for knob in KNOBS:
		var name_label := Label.new()
		name_label.text = knob.label
		name_label.custom_minimum_size.x = 110
		var slider := HSlider.new()
		slider.max_value = Night.STARTING_CASH
		slider.custom_minimum_size.x = 300
		slider.step = STEP
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(
			func(_v):
				_refresh(),
		)
		var effect := Label.new()
		effect.custom_minimum_size.x = 420
		effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		%KnobRows.add_child(name_label)
		%KnobRows.add_child(slider)
		%KnobRows.add_child(effect)
		sliders[knob.key] = slider
		effects[knob.key] = effect
		match knob.key:
			"build":
				slider.max_value = Allocation.BUILD_LADDER.size() # 0 = corridor shell, 1-4 = rungs
				slider.step = 1
			"depth":
				slider.max_value = floorf(Night.STARTING_CASH / Allocation.SPARE_COST) # 9 bench slots
				slider.step = 1
			"marketing":
				slider.max_value = MARKETING_CAP
			_:
				slider.max_value = Night.STARTING_CASH
				slider.step = STEP


func alloc() -> Dictionary:
	return {
		build = rung_dollars(int(sliders["build"].value)),
		quality = sliders["quality"].value,
		depth = sliders["depth"].value * Allocation.SPARE_COST,
		marketing = sliders["marketing"].value,
	}


func _refresh() -> void:
	var a := alloc()
	var reserve: float = Night.STARTING_CASH - (a.build + a.quality + a.depth + a.marketing)
	%ReserveLabel.text = "Unallocated: %s" % money(reserve)
	%ReserveLabel.add_theme_color_override(
		"font_color",
		Color.INDIAN_RED if reserve < 0.0 else Color.WHITE,
	)
	%RunButton.disabled = reserve < 0.0
	%StartButton.disabled = reserve < 0.0

	effects["build"].text = rung_text(a.build)
	effects["quality"].text = (
		"$0 — takes whoever answers the flyer"
		if a.quality == 0.0
		else "%s — signs mostly %s talent"
		% [money(a.quality), skill_word(minf(a.quality / Allocation.HIRE_TIER_DOLLARS, 1.0) * 10.0)]
	)
	effects["depth"].text = spares_text(a.depth)
	effects["marketing"].text = (
		"%s — opening reputation %.0f"
		% [money(a.marketing), Allocation.starting_rep_for(a.marketing)]
	)


func spares_text(budget: float) -> String:
	var spares := Allocation.spares_for(budget)
	if spares == 0:
		return "no bench"
	return "bench: %d on call ($%.0f/night idle)" % [spares, Allocation.ON_CALL_WAGE]


func rung_text(budget: float) -> String:
	var layout := Allocation.layout_for(budget)
	var text: String
	if layout.count("a") == 0:
		text = "corridor shell, no scares ($%d)" % int(Night.build_cost_for(layout))
	else:
		text = "%d scare rooms" % layout.count("a")
		var anims: int = layout.count("n")
		if anims > 0:
			text += " + %d animatronic%s" % [anims, "s" if anims > 1 else ""]
		text += " ($%d)" % int(Night.build_cost_for(layout))
	for rung in Allocation.BUILD_LADDER:
		if rung[0] > budget:
			return text + " — next: %d scares ($%d)" % [rung[1].count("a"), int(rung[0])]
	return text


func _on_run() -> void:
	var a := alloc()
	var t := Allocation.run_season(a, randi())
	%SeasonLog.clear()
	var prev := Allocation.opening_cash(a)
	%SeasonLog.append_text("Doors open with %s on hand.\n" % money(prev))
	for i in t.size():
		if i + 1 == Allocation.CASH_OUT_DAY:
			%SeasonLog.append_text(
				"[color=#8d99ae]The line packs from here to Halloween.[/color]\n"
			)
		var delta: float = t[i].cash - prev
		var color := "66bb6a" if delta >= 0.0 else "ef5350"
		%SeasonLog.append_text(
			"Oct %d: %s ([color=#%s]%s[/color])\n" % [i + 1, money(t[i].cash), color, money(delta)],
		)
		if t[i].cash < Night.LOAN_LIMIT:
			%SeasonLog.append_text(
				"[color=#ef5350]The bank calls your loan. Season over.[/color]\n"
			)
			return
		prev = t[i].cash
	%SeasonLog.append_text("[b]Halloween close: %s[/b]\n" % money(t[-1].cash))


func _on_start_october() -> void:
	GameState.alloc = alloc()
	get_tree().change_scene_to_file("res://game/main.tscn")


func money(x: float) -> String:
	return "-$%.0f" % absf(x) if x < 0.0 else "$%.0f" % x


func skill_word(skill: float) -> String:
	for band in SKILL_WORDS:
		if skill < band[0]:
			return band[1]
	return SKILL_WORDS[-1][1]


func rung_dollars(i: int) -> float:
	return Allocation.BASE_BUILD if i == 0 else Allocation.BUILD_LADDER[i - 1][0]


func rung_index(dollars: float) -> int:
	var idx := 0
	for i in Allocation.BUILD_LADDER.size():
		if Allocation.BUILD_LADDER[i][0] <= dollars:
			idx = i + 1
	return idx
