extends Control

const Night = preload("res://sim/night.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")
const Allocation = preload("res://sim/allocation.gd")
const Calendar = preload("res://sim/calendar.gd")
const Casting = preload("res://sim/casting.gd")
const Roster = preload("res://sim/roster.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")

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
	Rooms.SCARE: "A live actor, staffed by two. The big scares, but they can whiff,\nand actors draw wages every night.",
	Rooms.PAIR_SCARE: "A two-actor scene, four on staff with the rotation.\nMuch harder to see coming. Twice the wages.",
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

var weather: Array[String]

const WEATHER_WORDS := {
	"clear": "clear skies",
	"drizzle": "drizzle likely",
	"rain": "rain on the way",
}

const WEATHER_NOTES := {
	"drizzle": "The drizzle thinned the line a little.",
	"rain": "Rain kept the crowds home.",
}

var roster_seed := 0
var roster: Array[Dictionary] = []
var callout_rng := RandomNumberGenerator.new()
var pending_absent: Array = []
var pending_policy := Casting.NEVER

const SKILL_WORDS := [[4.0, "green"], [7.0, "solid"], [9.0, "strong"], [999.0, "headliner"]]


func _ready() -> void:
	rng.randomize()
	_build_toolbar()
	_build_slot_row()
	_build_pace_bar()
	_build_callout_banner()
	%RunButton.pressed.connect(_on_run_night)
	%ResetButton.pressed.connect(start_season)
	%PlanButton.pressed.connect(_on_back_to_planning)
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
		b.clip_text = true
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


func _build_callout_banner() -> void:
	var response_group := ButtonGroup.new()
	for b in [%DarkButton, %BenchButton, %PullButton]:
		b.toggle_mode = true
		b.button_group = response_group
	%DarkButton.pressed.connect(
		func():
			_choose_policy(Casting.NEVER),
	)
	%BenchButton.pressed.connect(
		func():
			_choose_policy(Casting.REASSIGN),
	)
	%PullButton.pressed.connect(
		func():
			_choose_policy(Casting.REASSIGN),
	)
	%PullButton.text = "Consolidate rooms"


func _build_roster_strip() -> void:
	for c in %RosterStrip.get_children():
		c.free()
	for i in roster.size():
		var chip := Button.new()
		chip.disabled = true # read-only this milestone; M3 makes them clickable
		chip.focus_mode = Control.FOCUS_NONE
		%RosterStrip.add_child(chip)
	_refresh_roster_strip()


func _refresh_roster_strip() -> void:
	var headcount := mini(Night.actors_for(layout), roster.size())
	for i in %RosterStrip.get_child_count():
		var chip: Button = %RosterStrip.get_child(i)
		var a: Dictionary = roster[i]
		var text := "%s · %s" % [a.name, skill_word(a.skill)]
		if a.observed_callouts > 0:
			text += " ×%d" % a.observed_callouts
		if i >= headcount:
			text += " · on call"
			chip.tooltip_text = "on call: $%.0f a night when idle, $%.0f when they perform" \
					% [Allocation.ON_CALL_WAGE, a.wage]
			chip.modulate = Color(1.0, 1.0, 1.0, 0.55)
		else:
			chip.tooltip_text = "$%.0f a night" % a.wage
			chip.modulate = Color.WHITE
		chip.text = text


func slot_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	return sb


func start_season() -> void:
	night = 1
	weather = Calendar.roll_season(rng.randi())
	roster_seed = rng.randi()
	callout_rng.seed = rng.randi()

	if not GameState.alloc.is_empty():
		var a: Dictionary = GameState.alloc
		layout = Allocation.layout_for(a.build)
		town = Town.new(Allocation.starting_rep_for(a.marketing))
		cash = Allocation.opening_cash(a)
	else:
		layout = []
		for i in ROOM_SLOTS:
			layout.append(Rooms.CORRIDOR)
		town = Town.new()
		cash = Night.STARTING_CASH - Night.build_cost_for(layout)
	_rebuild_roster()
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
	%CalloutBanner.visible = false
	pending_absent = []
	pending_policy = Casting.NEVER
	_build_roster_strip()
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
	if night == 1:
		_rebuild_roster()
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
	var day: String = Calendar.DAY_NAMES[Calendar.weekday(night)]
	%NightLabel.text = "%s, Oct %d · %s" % [day, night, WEATHER_WORDS[weather[night - 1]]] if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween · %s · %s" % [day, WEATHER_WORDS[weather[night - 1]]]

	var assignment: Dictionary = Casting.auto_assign(layout)

	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		b.text = TOOLS[layout[i]].to_upper()
		b.add_theme_stylebox_override("normal", slot_style(ROOM_COLORS[layout[i]]))
		b.add_theme_stylebox_override("hover", slot_style(ROOM_COLORS[layout[i]].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(ROOM_COLORS[layout[i]].darkened(0.15)))
		if assignment.has(i):
			var inits := []
			var short := false
			for ai in assignment[i]:
				if ai < roster.size():
					inits.append(initials(roster[ai].name))
				else:
					short = true
			var label: String = TOOLS[layout[i]].to_upper()
			if short:
				b.text = "%s\nshort-staffed" % label
			elif inits.size() == 4:
				b.text = "%s\n%s %s\n%s %s" % [label, inits[0], inits[1], inits[2], inits[3]]
			else:
				b.text = "%s\n%s" % [label, " ".join(inits)]
	_refresh_roster_strip()

	for b in %ToolBar.get_children():
		b.disabled = cheapest_place_cost(b.get_meta("type")) > cash

	var dark := (
		night <= Night.SEASON_NIGHTS and Allocation.is_dark(layout, tonight_demand(), night)
	)

	if dark:
		%CostPreview.text = "closed: $%.0f overhead" % Night.NIGHTLY_OVERHEAD
	else:
		%CostPreview.text = "staff %d, $%.0f wages + upkeep tonight, + $%.2f marketing per visitor" % [
			Night.staff_for(layout),
			Allocation.roster_wages(
				roster,
				mini(Night.actors_for(layout), roster.size()),
				[],
				Casting.NEVER,
			)
			+ Night.upkeep_for(layout) + Night.NIGHTLY_OVERHEAD,
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

	if not %RunButton.disabled and pending_absent.is_empty():
		%RunButton.text = "Closed tonight (−$%.0f)" % Night.NIGHTLY_OVERHEAD if dark else "Run night"

	if not pending_absent.is_empty():
		_preview_board()


func _on_run_night() -> void:
	var demand := tonight_demand()

	if Allocation.is_dark(layout, demand, night):
		cash -= Night.NIGHTLY_OVERHEAD
		_night_finish(
			"[b]%s, Oct %d[/b]  Closed tonight: too few would come out to cover the cast. −$%.0f keeps the lights on."
			% [Calendar.DAY_NAMES[Calendar.weekday(night)], night, Night.NIGHTLY_OVERHEAD]
		)
		return

	if pending_absent.is_empty():
		var absent := Roster.roll_callouts(roster, callout_rng)
		var headcount := mini(Night.actors_for(layout), roster.size())
		var performer_out := false
		for i in absent:
			if i < headcount:
				performer_out = true
		if not absent.is_empty() and performer_out:
			pending_absent = absent
			_show_banner()
			return
		pending_absent = absent # bench-only: no question, but counts still accrue
		pending_policy = Casting.REASSIGN
	_resolve_and_run(demand)


func _night_tick(t: float, cash_before: float, visitors: int) -> void:
	%CashLabel.text = money(lerpf(cash_before, cash, t))
	%NightLabel.text = "%s, Oct %d | %d visitors so far" % [
		Calendar.DAY_NAMES[Calendar.weekday(night)],
		night,
		int(visitors * t),
	]
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
	if not %RunButton.disabled:
		var dark := (
			night <= Night.SEASON_NIGHTS and Allocation.is_dark(layout, tonight_demand(), night)
		)
		%RunButton.text = "Closed tonight (−$%.0f)" % Night.NIGHTLY_OVERHEAD if dark else "Run night"
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
	else:
		%NightLog.append_text(
			"[color=#8d99ae]Forecast for %s: %s.[/color]\n"
			% [Calendar.DAY_NAMES[Calendar.weekday(night)], WEATHER_WORDS[weather[night - 1]]]
		)
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


func tonight_demand() -> int:
	return int(
		town.demand() * Calendar.weight_for(night) * Calendar.WEATHER[weather[night - 1]].mult
	)


func _on_back_to_planning() -> void:
	get_tree().change_scene_to_file("res://game/pivot.tscn")


func skill_word(skill: float) -> String:
	for band in SKILL_WORDS:
		if skill < band[0]:
			return band[1]
	return SKILL_WORDS[-1][1]


func initials(full_name: String) -> String:
	var out := ""
	for part in full_name.split(" "):
		if part.length() > 0:
			out += part[0]
	return out


func _choose_policy(policy: int) -> void:
	pending_policy = policy
	_preview_board()


func _preview_board() -> void:
	var board: Dictionary = Casting.resolve(layout, roster, pending_absent, pending_policy)
	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		var room: String = board.layout[i]
		b.add_theme_stylebox_override("normal", slot_style(ROOM_COLORS[room]))
		b.add_theme_stylebox_override("hover", slot_style(ROOM_COLORS[room].lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(ROOM_COLORS[room].darkened(0.15)))
		if room != layout[i]:
			if room == Rooms.CORRIDOR:
				b.text = "%s\ndark" % TOOLS[room].to_upper()
			else:
				b.text = "%s\nshorthanded" % TOOLS[room].to_upper()


func _show_banner() -> void:
	var assignment: Dictionary = Casting.auto_assign(layout)
	var room_of := { }
	for room_i in assignment:
		for ai in assignment[room_i]:
			room_of[ai] = room_i

	var lines := []
	for i in pending_absent:
		var a: Dictionary = roster[i]
		var nth: int = a.observed_callouts + 1
		var called := "%s called out." % a.name
		if nth > 1:
			called = "%s called out again, %s time this month." % [a.name, ordinal(nth)]
		lines.append(called + " " + consequence(i, room_of, assignment))
	%BannerLabel.text = " ".join(lines)

	var headcount := mini(Night.actors_for(layout), roster.size())
	var bench_free := 0
	for i in range(headcount, roster.size()):
		if not pending_absent.has(i):
			bench_free += 1
	var performer_holes := 0
	for i in pending_absent:
		if i < headcount:
			performer_holes += 1

	var next_up := ""
	for i in range(headcount, roster.size()):
		if not pending_absent.has(i):
			next_up = roster[i].name
			break

	%BenchButton.disabled = bench_free == 0
	%BenchButton.text = "Send in %s" % next_up if next_up != "" else "Send the bench"
	%BenchButton.tooltip_text = (
		"No one on call — cast depth buys a bench in pre-season."
		if bench_free == 0
		else "%s steps into the empty spot at full wage." % next_up
	)

	var half_rooms := 0
	var bench_left := bench_free
	var rooms := assignment.keys()
	rooms.sort()
	rooms.reverse() # bench fills late rooms first, same as fill_from_bench
	for room_i in rooms:
		if layout[room_i] != Rooms.SCARE:
			continue
		var present := 0
		for ai in assignment[room_i]:
			if ai < roster.size() and not pending_absent.has(ai):
				present += 1
		var fill := mini(Night.ACTORS_PER_SCARE - present, bench_left)
		bench_left -= fill
		if present + fill == 1:
			half_rooms += 1
	%PullButton.disabled = half_rooms < 2
	%PullButton.tooltip_text = (
		"Needs two half-staffed rooms to merge into one."
		if %PullButton.disabled
		else "Close the earlier hole and move its actor to fill the later one."
	)
	%DarkButton.button_pressed = true
	pending_policy = Casting.NEVER

	var never_board: Dictionary = Casting.resolve(layout, roster, pending_absent, Casting.NEVER)
	var goes_dark := false
	for i in layout.size():
		if Casting.needs_for(layout[i]) > 0 and never_board.layout[i] == Rooms.CORRIDOR:
			goes_dark = true
	%DarkButton.text = "Leave it dark" if goes_dark else "Play on short"
	%DarkButton.tooltip_text = (
		"Accept the hole; that room plays as a corridor tonight."
		if goes_dark
		else "Accept it; the scene runs without the full cast."
	)

	_preview_board()

	%CalloutBanner.visible = true
	%RunButton.text = "Open the doors"


func ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1:
			return "%dst" % n
		2:
			return "%dnd" % n
		3:
			return "%drd" % n
		_:
			return "%dth" % n


func _resolve_and_run(demand: int) -> void:
	var absent := pending_absent
	var policy := pending_policy
	pending_absent = []
	%CalloutBanner.visible = false
	for i in absent:
		roster[i].observed_callouts += 1
	var board: Dictionary = Casting.resolve(layout, roster, absent, policy)
	var bonus_row: Array = []
	for c in board.ceilings:
		bonus_row.append(Allocation.effective_bonus(c, interval))
	var r: Dictionary = Night.run(
		board.layout,
		interval,
		rng,
		demand,
		Walkthrough.PRIME_SCALE,
		"",
		0.0,
		bonus_row,
	)
	var headcount := mini(Night.actors_for(layout), roster.size())
	var wage_fix := Allocation.roster_wages(roster, headcount, absent, policy) \
			- Night.wages_for(board.layout)
	var profit: float = r.profit - wage_fix
	var capacity := int(Night.NIGHT_SECONDS / interval)
	var sold_out: bool = demand / Night.GROUP_SIZE > capacity
	town.record_night(r.satisfaction)
	var color := "66bb6a" if profit >= 0.0 else "ef5350"
	var line := "[b]%s, Oct %d[/b]  %d visitors × $%.0f tickets + $%.0f souvenirs, photos & merch − $%.0f costs = [color=#%s]%s[/color] %s" % [
		Calendar.DAY_NAMES[Calendar.weekday(night)],
		night,
		r.groups * Night.GROUP_SIZE,
		Night.TICKET_PRICE,
		r.gift,
		r.costs + wage_fix,
		color,
		money(profit),
		crowd_word(r.satisfaction),
	]
	var note := night_note(r)
	if note != "":
		line += " [color=#8d99ae]%s[/color]" % note
	for i in absent:
		line += " [color=#8d99ae]%s called out (%s).[/color]" \
				% [roster[i].name, ordinal(roster[i].observed_callouts)]
	%RunButton.disabled = true
	%ResetButton.disabled = true
	var cash_before := cash
	cash += profit
	var visitors: int = r.groups * Night.GROUP_SIZE
	var tween := create_tween()
	var duration := clampf(1.5 + r.groups * 0.03, 1.5, 5.0)
	tween.tween_method(_night_tick.bind(cash_before, visitors), 0.0, 1.0, duration)
	tween.tween_callback(_night_finish.bind(line))


func _rebuild_roster() -> void:
	var roster_rng := RandomNumberGenerator.new()
	roster_rng.seed = roster_seed
	var tier := 0.5
	var bench := 1
	if not GameState.alloc.is_empty():
		tier = minf(GameState.alloc.quality / Allocation.HIRE_TIER_DOLLARS, 1.0)
		bench = Allocation.spares_for(GameState.alloc.depth)
	var headcount := Night.actors_for(layout)
	roster = Roster.auto_hire(Roster.pool(roster_rng, headcount + bench, tier), headcount, bench)
	_build_roster_strip()


func consequence(actor_i: int, room_of: Dictionary, assignment: Dictionary) -> String:
	if not room_of.has(actor_i):
		return "They were on call; the board holds."
	var room_i: int = room_of[actor_i]
	var present := 0
	for ai in assignment[room_i]:
		if ai < roster.size() and not pending_absent.has(ai):
			present += 1
	if layout[room_i] == Rooms.PAIR_SCARE:
		if present >= Night.ACTORS_PER_SCARE:
			return "The scene plays on, smaller."
		return "The scene can't run."
	if present == 0:
		return "Both actors out; the room stands empty."
	return "No partner to run the rotation, so the room can't open."
