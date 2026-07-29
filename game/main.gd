extends Control

const Night = preload("res://sim/night.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")

const ROOM_SLOTS := 10

const ROOM_COLORS := {
	Rooms.CORRIDOR: Color(0.32, 0.32, 0.36),
	Rooms.SCARE: Color(0.58, 0.16, 0.16),
	Rooms.PAIR_SCARE: Color(0.42, 0.12, 0.50),
	Rooms.ANIMATRONIC: Color(0.16, 0.32, 0.58),
	Rooms.EFFECT: Color(0.10, 0.46, 0.40),
}

const TOOLS := {
	Rooms.CORRIDOR: "Corridor",
	Rooms.SCARE: "Scare",
	Rooms.PAIR_SCARE: "Pair scare",
	Rooms.ANIMATRONIC: "Animatronic",
	Rooms.EFFECT: "Effect",
}

const TOOL_TIPS := {
	Rooms.CORRIDOR: "A breather. Visitors settle their nerves,\nready to be scared properly again.\nToo many in a row and they get bored.",
	Rooms.SCARE: "A live actor. The big scares, but they can whiff,\nand actors draw wages every night.",
	Rooms.PAIR_SCARE: "Two actors working a scene together.\nMuch harder to see coming. Twice the wages.",
	Rooms.ANIMATRONIC: "A machine on a trigger. Never tires, draws no wage,\nnever quite as terrifying as a person. Heavy upkeep.",
	Rooms.EFFECT: "Fog and air blasts. Always fires,\nbut it's a jolt, not a fright.",
}

const PACES := { "Loose": 300.0, "Brisk": 200.0, "Packed": 120.0 }

const PACE_TIPS := {
	"Loose": "Actors fully reset between groups.\nBest scares, fewest visitors.",
	"Brisk": "A quicker line. Actors cut corners;\na few scares suffer.",
	"Packed": "Admits everyone in line. Rushed actors\nscare worse, and the town notices.",
}

var interval: float = PACES["Loose"]

var cash: float
var night: int
var layout: Array
var town
var selected_tool: String = Rooms.SCARE
var rng := RandomNumberGenerator.new()

var capacity_hints := 0
var wom_hints := 0
var wom_direction := 0

const FINAL_WEEK_NIGHT := 25 # WOM_DELAY + rep drift ≈ a week


func _ready() -> void:
	rng.randomize()
	_build_toolbar()
	_build_slot_row()
	_build_pace_bar()
	%RunButton.pressed.connect(_on_run_night)
	%ResetButton.pressed.connect(start_season)
	start_season()


func _build_toolbar() -> void:
	var tool_group := ButtonGroup.new()
	for type in TOOLS:
		var b := Button.new()
		b.set_meta("type", type)
		b.tooltip_text = TOOL_TIPS[type]
		b.toggle_mode = true
		b.button_group = tool_group
		b.text = "%s $%d" % [TOOLS[type], Night.BUILD_COST[type]]
		b.pressed.connect(
			func():
				selected_tool = type,
		)
		%ToolBar.add_child(b)


func _build_slot_row() -> void:
	for i in ROOM_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_slot_pressed.bind(i))
		%SlotRow.add_child(b)


func _build_pace_bar() -> void:
	var pace_group := ButtonGroup.new()
	for pace_name in PACES:
		var b := Button.new()
		b.set_meta("interval", PACES[pace_name])
		b.tooltip_text = PACE_TIPS[pace_name]
		b.toggle_mode = true
		b.button_group = pace_group
		b.text = pace_name
		b.button_pressed = PACES[pace_name] == interval
		b.pressed.connect(
			func():
				interval = PACES[pace_name]
				refresh(),
		)
		%PaceBar.add_child(b)


func slot_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	return sb


func start_season() -> void:
	night = 1
	layout = []
	for i in ROOM_SLOTS:
		layout.append(Rooms.CORRIDOR)
	town = Town.new()
	cash = Night.STARTING_CASH - Night.build_cost_for(layout)
	capacity_hints = 0
	wom_hints = 0
	wom_direction = 0
	%RunButton.text = "Run night"
	%RunButton.disabled = false
	%NightLog.clear()
	interval = PACES["Loose"]
	for b in %PaceBar.get_children():
		b.button_pressed = b.get_meta("interval") == interval
	selected_tool = Rooms.SCARE
	for b in %ToolBar.get_children():
		b.button_pressed = b.get_meta("type") == selected_tool
	refresh()


func _on_slot_pressed(i: int) -> void:
	if layout[i] == selected_tool:
		return
	var cost := place_cost(selected_tool, i)
	if cost > cash:
		_flash_cash()
		return
	cash -= cost
	layout[i] = selected_tool
	refresh()


func place_cost(type: String, i: int) -> float:
	var cost: float = Night.BUILD_COST[type]
	if night == 1:
		cost -= Night.BUILD_COST[layout[i]] # blueprint phase: swap refunds the old room
	return cost


func cheapest_place_cost(type: String) -> float:
	var cheapest := INF
	for i in layout.size():
		if layout[i] != type:
			cheapest = minf(cheapest, place_cost(type, i))
	return cheapest


func _flash_cash() -> void:
	%CashLabel.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(%CashLabel, "modulate", Color.WHITE, 0.4)


func refresh() -> void:
	%CashLabel.text = money(cash)
	%CashLabel.add_theme_color_override(
		"font_color",
		Color.INDIAN_RED if cash < 0.0 else Color.WHITE,
	)
	%NightLabel.text = "Oct %d" % night if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween"

	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		b.text = TOOLS[layout[i]].to_upper()
		b.add_theme_stylebox_override("normal", slot_style(ROOM_COLORS[layout[i]]))
		b.add_theme_stylebox_override("hover", slot_style(ROOM_COLORS[layout[i]].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(ROOM_COLORS[layout[i]].darkened(0.15)))

	for b in %ToolBar.get_children():
		b.disabled = cheapest_place_cost(b.get_meta("type")) > cash

	%CostPreview.text = "staff %d, $%.0f wages + upkeep tonight, + $%.2f marketing per visitor" % [
		Night.staff_for(layout),
		Night.wages_for(layout) + Night.upkeep_for(layout) + Night.NIGHTLY_OVERHEAD,
		Night.MARKETING_PER_VISITOR,
	]

	var strain := "actors fully reset"
	if interval <= PACES["Packed"]:
		strain = "actors sprinting between scares"
	elif interval <= PACES["Brisk"]:
		strain = "actors hustling"
	%PaceLabel.text = "Line pace: up to %d visitors a night, %s" % [
		int(Night.NIGHT_SECONDS / interval) * Night.GROUP_SIZE,
		strain,
	]
	%BlueprintNote.visible = night == 1


func _on_run_night() -> void:
	var demand: int = town.demand()
	var capacity := int(Night.NIGHT_SECONDS / interval)
	var r: Dictionary = Night.run(layout, interval, rng, demand)
	var sold_out: bool = demand / Night.GROUP_SIZE > capacity
	town.record_night(r.satisfaction)
	var color := "66bb6a" if r.profit >= 0.0 else "ef5350"
	var line := "[b]Oct %d[/b]  %d visitors × $%.0f tickets + $%.0f souvenirs, photos & merch − $%.0f costs = [color=#%s]%s[/color]. %s" % [
		night,
		r.groups * Night.GROUP_SIZE,
		Night.TICKET_PRICE,
		r.gift,
		r.costs,
		color,
		money(r.profit),
		crowd_word(r.satisfaction),
	]
	var note := night_note(r)
	if note != "":
		line += " [color=#8d99ae]%s[/color]" % note
	if sold_out:
		var turned_away: int = demand - r.groups * Night.GROUP_SIZE
		line += " [color=#e0a458]Sold out! Turned away ~%d (about %s in tickets).[/color]" % [
			turned_away,
			money(turned_away * Night.TICKET_PRICE),
		]
		if interval > PACES["Packed"] and capacity_hints < 2:
			capacity_hints += 1
			line += " [color=#8d99ae]A faster line pace would admit more.[/color]"
	var m: float = town.momentum()
	var dir := 1 if m >= 4.0 else (-1 if m <= -4.0 else 0)
	if dir != 0:
		if dir != wom_direction:
			wom_direction = dir
			wom_hints = 0
		if wom_hints < 2 and not (dir < 0 and night >= FINAL_WEEK_NIGHT):
			wom_hints += 1
			line += " [color=#8d99ae]%s[/color]" % (
				"Good word is getting around; expect bigger crowds in a few nights."
				if dir > 0
				else "Bad word is spreading; crowds will thin soon."
			)
	%RunButton.disabled = true
	%ResetButton.disabled = true
	var cash_before := cash
	cash += r.profit
	var visitors: int = r.groups * Night.GROUP_SIZE
	var tween := create_tween()
	var duration := clampf(1.5 + r.groups * 0.03, 1.5, 5.0)
	tween.tween_method(_night_tick.bind(cash_before, visitors), 0.0, 1.0, duration)
	tween.tween_callback(_night_finish.bind(line))


func _night_tick(t: float, cash_before: float, visitors: int) -> void:
	%CashLabel.text = money(lerpf(cash_before, cash, t))
	%NightLabel.text = "Oct %d | %d visitors so far" % [night, int(visitors * t)]
	for i in %SlotRow.get_child_count():
		var b: Button = %SlotRow.get_child(i)
		b.modulate = Color(1.4, 1.4, 1.4) if i == int(t * 40.0) % 10 else Color.WHITE


func _night_finish(line: String) -> void:
	%RunButton.disabled = false
	%ResetButton.disabled = false

	for b in %SlotRow.get_children():
		b.modulate = Color.WHITE
	%NightLog.append_text(line + "\n")
	night += 1
	if cash < Night.LOAN_LIMIT:
		%NightLog.append_text("[color=#ef5350]The bank calls your loan. Season over.[/color]\n")
		%RunButton.text = "Bankrupt: %s" % money(cash)
		%RunButton.disabled = true
		refresh()
		return
	if night == 2:
		%NightLog.append_text(
			"[color=#8d99ae]The doors are open. You can still build any night; new rooms now cost full price, no refunds.[/color]\n"
		)
	if night == FINAL_WEEK_NIGHT:
		%NightLog.append_text(
			"[color=#8d99ae]Final week. Whatever the town says about you now, it won't get around before Halloween.[/color]\n"
		)
	if night > Night.SEASON_NIGHTS:
		%RunButton.text = "Season over: %s" % money(cash)
		%RunButton.disabled = true
	refresh()


func crowd_word(sat: float) -> String:
	if sat >= 80.0:
		return "The crowd left raving."
	if sat >= 60.0:
		return "Good screams tonight."
	if sat >= 45.0:
		return "Mixed reactions."
	if sat >= 30.0:
		return "People left flat."
	return "Walkouts and refund demands."


func night_note(r: Dictionary) -> String:
	var visitors: int = r.groups * Night.GROUP_SIZE
	var per_visitor: float = Night.TICKET_PRICE + r.gift / visitors - Night.MARKETING_PER_VISITOR
	var fixed := Night.wages_for(layout) + Night.upkeep_for(layout) + Night.NIGHTLY_OVERHEAD
	var break_even := ceili(fixed / per_visitor)
	var pace_cap := int(Night.NIGHT_SECONDS / interval) * Night.GROUP_SIZE

	if r.satisfaction >= 60.0:
		if r.profit < 0.0:
			if break_even > pace_cap:
				return "They loved it, but even a sold-out night at this pace can't cover these costs."
			return "They loved it; word just hasn't gotten around. About %d visitors a night would pay for all this." % break_even
		return ""
	if interval <= PACES["Packed"]:
		return "The actors run ragged at this pace."
	if r.boredom >= 6.0:
		return "Long dead stretches between scares."
	if trailing_corridors() >= 2:
		return "They walked out through quiet rooms; the ending fell flat."
	if r.misses >= 2.5:
		return "Rough night: scare after scare just whiffed."
	return "The scares came too thick and fast to land."


func trailing_corridors() -> int:
	var n := 0
	var i := layout.size() - 1
	while i >= 0 and layout[i] == Rooms.CORRIDOR:
		n += 1
		i -= 1
	return n


func money(x: float) -> String:
	return "-$%.0f" % absf(x) if x < 0.0 else "$%.0f" % x
