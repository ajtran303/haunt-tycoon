extends Control

const Night = preload("res://sim/night.gd")
const Rooms = preload("res://sim/rooms.gd")
const Allocation = preload("res://sim/allocation.gd")
const Preseason = preload("res://sim/preseason.gd")
const MainUI = preload("res://game/main.gd")

enum Phase {
	BUILD,
	MARSHAL,
	CASTING,
	MARKETING,
	PREVIEW,
	OCT1,
}
const PHASE_NAMES := ["Build", "Marshal", "Casting", "Marketing", "Preview", "Oct 1"]

# Keep byte-equal to REFERENCE in tests/test_preseason.gd.
const REFERENCE := { build = 11_000.0, quality = 9_000.0, depth = 5_000.0, marketing = 6_000.0 }

const ROOM_SLOTS := 10

var phase: int = Phase.BUILD
var layout: Array = []
var alloc: Dictionary = REFERENCE.duplicate()
var preview_planned := true
var seed_val := 0
var roster: Array[Dictionary] = []
var selected_tool: String = Rooms.SCARE
var phase_started_ms := 0
var durations := { }


func _ready() -> void:
	seed_val = randi()
	layout = Allocation.layout_for(REFERENCE.build)
	_build_rail()
	_build_toolbar()
	_build_slot_row()
	_rebuild_roster()
	%CashChart.draw.connect(_on_chart_draw)
	%NextButton.pressed.connect(_on_next)
	%MarshalDialog.add_cancel_button("Keep building")
	%MarshalDialog.confirmed.connect(
		func():
			enter_phase(Phase.CASTING),
	)
	%MarshalDialog.canceled.connect(
		func():
			enter_phase(Phase.BUILD),
	)
	phase_started_ms = Time.get_ticks_msec()
	refresh()


func projected_phases() -> Dictionary:
	return Preseason.run_phases(alloc, layout, roster.size(), preview_planned)


func posted_entries() -> int:
	match phase:
		Phase.BUILD, Phase.MARSHAL:
			return 0
		Phase.CASTING:
			return 2
		Phase.MARKETING:
			return 3
		Phase.PREVIEW:
			return 6
		_:
			return projected_phases().ledger.size()


func enter_phase(p: int) -> void:
	var name: String = PHASE_NAMES[phase]
	var elapsed := (Time.get_ticks_msec() - phase_started_ms) / 1000.0
	durations[name] = durations.get(name, 0.0) + elapsed
	print("phase %s: %.1fs" % [name, durations[name]])
	phase = p
	phase_started_ms = Time.get_ticks_msec()
	refresh()


func _on_next() -> void:
	match phase:
		Phase.BUILD:
			_on_call_marshal()
		_:
			pass # casting, marketing, preview arrive in sub-step 3


func _on_call_marshal() -> void:
	enter_phase(Phase.MARSHAL)
	var cap := Preseason.marshal_cap(layout)
	var floor_interval := Preseason.dispatch_floor(layout)
	%MarshalDialog.dialog_text = (
		"The fire marshal walks the building.\n\n" + "Occupancy: %d inside at a time.\n" % cap
		+ pace_verdict(floor_interval)
		+ "\n\nPermit fee %s. Stamp it, and the layout is final for the season."
		% money(Preseason.PERMIT_FEE)
	)
	%MarshalDialog.popup_centered()


func pace_verdict(floor_interval: float) -> String:
	if floor_interval <= MainUI.PACES["Packed"]:
		return "Certified for a packed line: every pace is legal."
	if floor_interval <= MainUI.PACES["Brisk"]:
		return "Blinds and props crowd the exits. No packed line; brisk at most, and sellout nights will clip."
	if floor_interval <= MainUI.PACES["Loose"]:
		return "The exits barely clear code. Loose pace only."
	return "Groups must trickle in %d seconds apart. This building can't run a line." % int(
		ceil(floor_interval)
	)


func _build_rail() -> void:
	for i in PHASE_NAMES.size():
		var l := Label.new()
		l.text = PHASE_NAMES[i]
		%PhaseRail.add_child(l)
		if i < PHASE_NAMES.size() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.modulate = Color(1, 1, 1, 0.4)
			%PhaseRail.add_child(arrow)


func _refresh_rail() -> void:
	for i in PHASE_NAMES.size():
		var l: Label = %PhaseRail.get_child(i * 2)
		var col := Color(1, 1, 1, 0.4)
		if i == phase:
			col = Color.WHITE
		elif i < phase:
			col = Color(0.4, 0.73, 0.42)
		l.add_theme_color_override("font_color", col)


func _build_toolbar() -> void:
	var group := ButtonGroup.new()
	for type in MainUI.TOOLS:
		var b := Button.new()
		b.set_meta("type", type)
		b.tooltip_text = MainUI.TOOL_TIPS[type]
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s $%d" % [MainUI.TOOLS[type], Night.BUILD_COST[type]]
		b.button_pressed = type == selected_tool
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
		b.clip_text = true
		b.pressed.connect(_on_slot_pressed.bind(i))
		%SlotRow.add_child(b)


func _on_slot_pressed(i: int) -> void:
	if phase != Phase.BUILD:
		return
	if layout[i] == selected_tool:
		return
	if place_cost(selected_tool, i) > build_cash_left():
		return
	layout[i] = selected_tool
	_rebuild_roster()
	refresh()


func place_cost(type: String, i: int) -> float:
	return Night.BUILD_COST[type] - Night.BUILD_COST[layout[i]]


func cheapest_place_cost(type: String) -> float:
	var cheapest := INF
	for i in layout.size():
		if layout[i] != type:
			cheapest = minf(cheapest, place_cost(type, i))
	return cheapest


func build_cash_left() -> float:
	return Night.STARTING_CASH - Night.build_cost_for(layout)


func _rebuild_roster() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 300_000
	roster = Allocation.roster_for(alloc, rng, layout)


func slot_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	return sb


func refresh() -> void:
	var p := projected_phases()
	_refresh_rail()
	_refresh_build()
	_refresh_ledger(p)
	%CashChart.queue_redraw()
	%NextButton.text = next_text()
	%NextButton.disabled = phase != Phase.BUILD


func next_text() -> String:
	match phase:
		Phase.BUILD:
			return "Call the fire marshal"
		_:
			return "%s (next sub-step)" % PHASE_NAMES[phase]


func _refresh_build() -> void:
	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		b.text = MainUI.TOOLS[layout[i]].to_upper()
		var c: Color = MainUI.ROOM_COLORS[layout[i]]
		b.add_theme_stylebox_override("normal", slot_style(c))
		b.add_theme_stylebox_override("hover", slot_style(c.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(c.darkened(0.15)))
		b.disabled = phase != Phase.BUILD
	for b in %ToolBar.get_children():
		b.disabled = cheapest_place_cost(b.get_meta("type")) > build_cash_left()
	%ToolBar.visible = phase == Phase.BUILD
	%BuildNote.visible = phase == Phase.BUILD
	%BudgetLabel.text = "Build %s • %d actors to staff • %s unspent" % [
		money(Night.build_cost_for(layout)),
		Night.actors_for(layout),
		money(build_cash_left()),
	]


func _refresh_ledger(p: Dictionary) -> void:
	%Ledger.clear()
	var posted := posted_entries()
	%Ledger.append_text("[b]September ledger[/b]  opening cash %s\n" % money(Night.STARTING_CASH))
	for i in p.ledger.size():
		var e: Dictionary = p.ledger[i]
		var amount_col := "66bb6a" if e.amount >= 0.0 else "ef5350"
		var line := "%s  [color=#%s]%s[/color]  →  %s" % [
			e.label,
			amount_col,
			money(e.amount),
			money(e.cash),
		]
		if i >= posted:
			line = "[color=#8d99ae]%s (projected)[/color]" % line
		%Ledger.append_text(line + "\n")
	%Ledger.append_text(
		"\nSeptember low point: %s (loan limit %s)\n"
		% [money(trough_of(p)), money(Night.LOAN_LIMIT)]
	)


func trough_of(p: Dictionary) -> float:
	var t: float = Night.STARTING_CASH
	for e in p.ledger:
		t = minf(t, e.cash)
	return t


func _on_chart_draw() -> void:
	var chart: Control = %CashChart
	var p := projected_phases()
	var cashes: Array = [Night.STARTING_CASH]
	for e in p.ledger:
		cashes.append(e.cash)
	var lo: float = Night.LOAN_LIMIT
	var hi: float = Night.STARTING_CASH
	for c in cashes:
		lo = minf(lo, c)
		hi = maxf(hi, c)
	lo -= 2_000.0
	hi += 2_000.0
	var w := chart.size.x
	var h := chart.size.y
	var font := get_theme_default_font()
	var fs := get_theme_default_font_size()

	var limit_y: float = remap(Night.LOAN_LIMIT, lo, hi, h, 0.0)
	chart.draw_dashed_line(
		Vector2(0, limit_y),
		Vector2(w, limit_y),
		Color(0.94, 0.33, 0.31, 0.8),
		1.0,
		6.0,
	)
	chart.draw_string(
		font,
		Vector2(4, limit_y - 4),
		"loan limit %s" % money(Night.LOAN_LIMIT),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Color(0.94, 0.33, 0.31),
	)

	var posted := posted_entries()
	var pts: Array[Vector2] = []
	for i in cashes.size():
		pts.append(
			Vector2(
				remap(float(i), 0.0, float(cashes.size() - 1), 8.0, w - 8.0),
				remap(cashes[i], lo, hi, h - 4.0, 4.0),
			)
		)
	for i in range(1, pts.size()):
		var col := Color.WHITE if i <= posted else Color(1, 1, 1, 0.35)
		chart.draw_line(pts[i - 1], pts[i], col, 2.0)
	for i in pts.size():
		chart.draw_circle(pts[i], 3.0, Color.WHITE if i <= posted else Color(1, 1, 1, 0.35))


func money(x: float) -> String:
	return "-$%.0f" % absf(x) if x < 0.0 else "$%.0f" % x
