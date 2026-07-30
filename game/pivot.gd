extends Control

const Allocation = preload("res://sim/allocation.gd")
const Night = preload("res://sim/night.gd")

const STEP := 500.0

const KNOBS := [
	{ key = "build", label = "Build" },
	{ key = "quality", label = "Cast quality" },
	{ key = "depth", label = "Cast depth" },
	{ key = "marketing", label = "Marketing" },
]

var sliders := { }
var effects := { }


func _ready() -> void:
	_build_rows()
	%RunButton.pressed.connect(_on_run)
	%StartButton.pressed.connect(_on_start_october)
	_refresh()


func _build_rows() -> void:
	for knob in KNOBS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = knob.label
		name_label.custom_minimum_size.x = 110
		var slider := HSlider.new()
		slider.max_value = Night.STARTING_CASH
		slider.step = STEP
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(
			func(_v):
				_refresh(),
		)
		var effect := Label.new()
		effect.custom_minimum_size.x = 340
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(effect)
		%KnobRows.add_child(row)
		sliders[knob.key] = slider
		effects[knob.key] = effect


func alloc() -> Dictionary:
	return {
		build = sliders["build"].value,
		quality = sliders["quality"].value,
		depth = sliders["depth"].value,
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
		"+%.1f actor ceiling at a loose pace" % Allocation.ceiling_bonus_for(a.quality)
	)
	effects["depth"].text = spares_text(a.depth)
	effects["marketing"].text = (
		"opening reputation %.0f" % Allocation.starting_rep_for(a.marketing)
	)


func spares_text(budget: float) -> String:
	var spares := Allocation.spares_for(budget)
	var text := (
		"no spare actors"
		if spares == 0
		else "%d spare actor%s" % [spares, "s" if spares > 1 else ""]
	)
	if budget < Night.STARTING_CASH:
		text += " — next spare at $%d" % int((spares + 1) * Allocation.SPARE_COST)
	return text


func rung_text(budget: float) -> String:
	var layout := Allocation.layout_for(budget)
	var text := "%d scare rooms" % layout.count("a")
	var anims: int = layout.count("n")
	if anims > 0:
		text += " + %d animatronic%s" % [anims, "s" if anims > 1 else ""]
	text += " ($%d)" % int(Night.build_cost_for(layout))
	for rung in Allocation.BUILD_LADDER:
		if rung[0] > budget:
			return text + " — next tier at $%d" % int(rung[0])
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
		var delta: float = t[i] - prev
		var color := "66bb6a" if delta >= 0.0 else "ef5350"
		%SeasonLog.append_text(
			"Oct %d: %s ([color=#%s]%s[/color])\n" % [i + 1, money(t[i]), color, money(delta)],
		)
		if t[i] < Night.LOAN_LIMIT:
			%SeasonLog.append_text(
				"[color=#ef5350]The bank calls your loan. Season over.[/color]\n"
			)
			return
		prev = t[i]
	%SeasonLog.append_text("[b]Halloween close: %s[/b]\n" % money(t[-1]))


func _on_start_october() -> void:
	GameState.alloc = alloc()
	get_tree().change_scene_to_file("res://game/main.tscn")


func money(x: float) -> String:
	return "-$%.0f" % absf(x) if x < 0.0 else "$%.0f" % x
