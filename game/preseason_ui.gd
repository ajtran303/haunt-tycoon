extends Control

const Night = preload("res://sim/night.gd")
const Rooms = preload("res://sim/rooms.gd")
const Allocation = preload("res://sim/allocation.gd")
const Preseason = preload("res://sim/preseason.gd")
const MainUI = preload("res://game/main.gd")
const Casting = preload("res://sim/casting.gd")

enum Phase {
	BUILD,
	CASTING,
	MARKETING,
	PREVIEW,
	OCT1,
}
const PHASE_NAMES := ["Build", "Casting", "Marketing", "Preview", "Oct 1"]

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
var preview_sat := -1.0


func _ready() -> void:
	seed_val = randi()
	layout = Allocation.layout_for(REFERENCE.build)
	_build_rail()
	_build_toolbar()
	_build_slot_row()
	_rebuild_roster()
	%CashChart.draw.connect(_on_chart_draw)
	%NextButton.pressed.connect(_on_next)
	%SkipButton.pressed.connect(_on_skip_preview)
	%MarketingSlider.value_changed.connect(
		func(v: float):
			alloc.marketing = v
			refresh(),
	)
	refresh()


func projected_phases() -> Dictionary:
	return Preseason.run_phases(alloc, layout, roster.size(), preview_planned)


func posted_entries() -> int:
	match phase:
		Phase.BUILD:
			return 0
		Phase.CASTING:
			return 1
		Phase.MARKETING:
			return 2
		Phase.PREVIEW:
			return 5
		_:
			return projected_phases().ledger.size()


func enter_phase(p: int) -> void:
	phase = p
	refresh()


func _on_next() -> void:
	match phase:
		Phase.BUILD:
			enter_phase(Phase.CASTING)
		Phase.CASTING:
			enter_phase(Phase.MARKETING)
		Phase.MARKETING:
			enter_phase(Phase.PREVIEW)
		Phase.PREVIEW:
			preview_planned = true
			preview_sat = Allocation.preview(alloc, seed_val, Casting.REASSIGN, layout)
			enter_phase(Phase.OCT1)
		_:
			_open_the_doors()


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
	_refresh_phase_panels(p)
	_refresh_ledger(p)
	%CashChart.queue_redraw()
	%NextButton.text = next_text()
	%NextButton.disabled = false
	%SkipButton.visible = phase == Phase.PREVIEW


func next_text() -> String:
	match phase:
		Phase.BUILD:
			return "Finish the build (%s)" % money(Night.build_cost_for(layout))
		Phase.CASTING:
			return (
				"The layout is final. Casting spend %s; %d on the bench at $%.0f a night on call."
				% [
					money(alloc.quality),
					Allocation.spares_for(alloc.depth),
					Allocation.ON_CALL_WAGE,
				]
			)
		Phase.MARKETING:
			return "Lock the campaign (%s)" % money(alloc.marketing)
		Phase.PREVIEW:
			return "Play the press preview (−%s)" % money(preview_cost())
		_:
			return "Open the doors"


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
	var goals := []
	for g in Preseason.SEASON_GOALS:
		goals.append("%s %s" % [money(g.cash), g.name])
	%Ledger.append_text("Halloween close: %s\n" % " • ".join(goals))


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


func _on_skip_preview() -> void:
	preview_planned = false
	preview_sat = -1.0
	enter_phase(Phase.OCT1)


func preview_cost() -> float:
	return Night.wages_for(layout) + Night.NIGHTLY_OVERHEAD + Night.upkeep_for(layout)


func _refresh_phase_panels(p: Dictionary) -> void:
	%CastingPanel.visible = phase == Phase.CASTING
	%MarketingPanel.visible = phase == Phase.MARKETING
	%PreviewPanel.visible = phase >= Phase.PREVIEW

	if phase == Phase.CASTING:
		_refresh_chips()
		%CastingLabel.text = (
			"Your casting director signed these. Casting spend %s; the bench stays on call at $%.0f a night."
			% [money(alloc.quality), Allocation.ON_CALL_WAGE]
		)

	if phase == Phase.MARKETING:
		var push: float = alloc.marketing * Preseason.PRESALE_PUSH_SHARE
		var presold := int(push / Preseason.PRESALE_PUSH_PER_TICKET)
		%MarketingLabel.text = (
			"Awareness %s → the town opens at rep %.0f.\nPresale push %s → %d tickets sold now for %s, redeemed off October's door."
			% [
				money(alloc.marketing - push),
				Allocation.starting_rep_for(alloc.marketing - push),
				money(push),
				presold,
				money(presold * Night.TICKET_PRICE * (1.0 - Preseason.PRESALE_DISCOUNT)),
			]
		)

	if phase == Phase.PREVIEW:
		%PreviewLabel.text = (
			"One comped, full-detail night for the press before doors open: real wages and overhead (−%s), no revenue. What they print seeds opening night."
			% money(preview_cost())
		)
		%PreviewBlurb.text = ""
	elif phase == Phase.OCT1:
		%PreviewLabel.text = "The press has spoken." if preview_sat >= 0.0 else ""
		%PreviewBlurb.text = (
			"[i]%s[/i] — The Gazette, dress-night preview" % press_blurb(preview_sat)
			if preview_sat >= 0.0
			else "[color=#8d99ae]No press came. The doors open cold.[/color]"
		)


func _refresh_chips() -> void:
	for c in %RosterChips.get_children():
		c.free()
	var headcount := mini(Night.actors_for(layout), roster.size())
	for i in roster.size():
		var chip := Button.new()
		chip.disabled = true
		chip.focus_mode = Control.FOCUS_NONE
		var a: Dictionary = roster[i]
		chip.text = "%s | %s" % [a.name, skill_word(a.skill)]
		if i >= headcount:
			chip.text += " | on call"
			chip.modulate = Color(1.0, 1.0, 1.0, 0.55)
			chip.tooltip_text = (
				"on call: $%.0f a night when idle, $%.0f when they perform"
				% [Allocation.ON_CALL_WAGE, a.wage]
			)
		else:
			chip.tooltip_text = "$%.0f a night" % a.wage
		%RosterChips.add_child(chip)


func skill_word(skill: float) -> String:
	for band in MainUI.SKILL_WORDS:
		if skill < band[0]:
			return band[1]
	return MainUI.SKILL_WORDS[-1][1]


func press_blurb(sat: float) -> String:
	if sat >= 80.0:
		return "\"The scariest thing this town has built in years. Go.\""
	if sat >= 60.0:
		return "\"Worth the ticket. Bring someone to grab.\""
	if sat >= 45.0:
		return "\"Some real scares in there, between long hallways.\""
	if sat >= 30.0:
		return "\"An ambitious haunt that isn't ready yet.\""
	return "\"Skip it. The parking queue is scarier than the house.\""


func _open_the_doors() -> void:
	GameState.alloc = alloc.duplicate()
	GameState.layout = layout.duplicate()
	GameState.roster_seed = seed_val + 300_000
	var phases := projected_phases()
	phases.preview_sat = preview_sat
	GameState.phases = phases
	get_tree().change_scene_to_file("res://game/main.tscn")
