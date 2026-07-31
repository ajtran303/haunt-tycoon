extends Control

const Night = preload("res://sim/night.gd")
const Town = preload("res://sim/town.gd")
const Rooms = preload("res://sim/rooms.gd")
const Allocation = preload("res://sim/allocation.gd")
const Calendar = preload("res://sim/calendar.gd")
const Casting = preload("res://sim/casting.gd")
const Roster = preload("res://sim/roster.gd")
const Walkthrough = preload("res://sim/walkthrough.gd")
const Records = preload("res://sim/records.gd")

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
var lock_note_shown := false
var final_week_shown := false

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

const CONSEQUENCES := {
	"bench": ["They were on call; the board holds.", "They were on call; the board holds."],
	"pair_smaller": [
		"The scene plays on, easier to see coming.",
		"%s scenes play on, easier to see coming.",
	],
	"pair_dark": ["The scene can't run tonight.", "%s scenes can't run tonight."],
	"scare_empty": ["The room stands empty tonight.", "%s rooms stand empty tonight."],
	"scare_solo": ["No partner for the rotation; the room can't open.", "%s rooms can't open."],
}

const COUNT_WORDS := ["", "", "Both", "Three", "Four", "Five"]

var force_open := false

var records := { }
var sample_rng := RandomNumberGenerator.new()
var reviews_shown := 0


func _ready() -> void:
	rng.randomize()
	_build_toolbar()
	_build_slot_row()
	_build_pace_bar()
	_build_callout_banner()
	%RunButton.pressed.connect(_on_run_night)
	%OpenAnywayButton.pressed.connect(_on_open_anyway)
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
	%BannerLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%BannerLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var response_group := ButtonGroup.new()
	for b in [%AcceptButton, %RespondButton]:
		b.toggle_mode = true
		b.button_group = response_group
	%AcceptButton.pressed.connect(
		func():
			_choose_policy(Casting.NEVER),
	)
	%RespondButton.pressed.connect(
		func():
			_choose_policy(Casting.REASSIGN),
	)

	%GoDarkButton.pressed.connect(_on_go_dark)


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
		var text := "%s | %s" % [a.name, skill_word(a.skill)]
		if a.observed_callouts > 0:
			text += " ×%d" % a.observed_callouts
		if i >= headcount:
			text += " | on call"
			chip.tooltip_text = "on call: $%.0f a night when idle, $%.0f when they perform" \
					% [Allocation.ON_CALL_WAGE, a.wage]
			chip.modulate = Color(1.0, 1.0, 1.0, 0.55)
		else:
			chip.tooltip_text = "$%.0f a night" % a.wage
			chip.modulate = Color.WHITE
		chip.text = text
		if records.has("careers") and records.careers.has(i):
			var c: Dictionary = records.careers[i]
			chip.tooltip_text += "\n%d screams | %d whiffs | best night Oct %d" % [
				c.screams,
				c.whiffs,
				c.best_night,
			]
			if c.assists > 0:
				chip.tooltip_text += " | %d assists" % c.assists


func slot_style(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(6)
	return sb


func start_season() -> void:
	night = 1
	force_open = false
	lock_note_shown = false
	final_week_shown = false
	weather = Calendar.roll_season(rng.randi())
	roster_seed = rng.randi()
	callout_rng.seed = rng.randi()
	records = { careers = { }, nights = [], box = [] }
	sample_rng.seed = rng.randi()
	reviews_shown = 0

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
	if night > 1:
		return
	if layout[i] == selected_tool:
		return
	var cost := place_cost(selected_tool, i)
	if cost > cash:
		_flash_cash()
		return
	cash -= cost
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
	%NightLabel.text = "%s, Oct %d | %s" % [day, night, WEATHER_WORDS[weather[night - 1]]] if night <= Night.SEASON_NIGHTS else "Season over"
	if night == Night.SEASON_NIGHTS:
		%NightLabel.text = "Halloween | %s | %s" % [day, WEATHER_WORDS[weather[night - 1]]]

	var assignment: Dictionary = Casting.auto_assign(layout)

	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		b.text = slot_caption(i, assignment)
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
		var gate := tonight_demand()
		var door := gate * (Night.TICKET_PRICE - Night.MARKETING_PER_VISITOR)
		var staffing := Allocation.roster_wages(
			roster,
			mini(Night.actors_for(layout), roster.size()),
			[],
			Casting.NEVER,
		) + Night.upkeep_for(layout)
		%CostPreview.text = (
			"Quiet %s: maybe %d come through (~$%.0f at the door) against ~$%.0f to staff the rooms. Dark costs only the $%.0f overhead per night."
			% [
				Calendar.DAY_NAMES[Calendar.weekday(night)],
				gate,
				door,
				staffing,
				Night.NIGHTLY_OVERHEAD,
			]
		)
		%OpenAnywayButton.text = "Open anyway (about −$%.0f)" % (
			Night.NIGHTLY_OVERHEAD + staffing - door
		)
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
	%ToolBar.visible = night == 1
	%BlueprintNote.visible = night == 1

	if not %RunButton.disabled and pending_absent.is_empty():
		if dark:
			var n := dark_stretch()
			if n == 1:
				%RunButton.text = "Stay dark (−$%.0f)" % Night.NIGHTLY_OVERHEAD
			elif night + n > Night.SEASON_NIGHTS:
				%RunButton.text = "Dark to season's end (−$%.0f)" % (Night.NIGHTLY_OVERHEAD * n)
			else:
				%RunButton.text = "Dark until %s (−$%.0f)" % [
					Calendar.DAY_NAMES[Calendar.weekday(night + n)],
					Night.NIGHTLY_OVERHEAD * n,
				]
		else:
			%RunButton.text = "Run night"

	%OpenAnywayButton.visible = dark and pending_absent.is_empty() and not %RunButton.disabled

	if not pending_absent.is_empty():
		_preview_board()


func _on_open_anyway() -> void:
	force_open = true
	%OpenAnywayButton.visible = false
	_on_run_night()


func _on_run_night() -> void:
	var demand := tonight_demand()

	if not force_open and Allocation.is_dark(layout, demand, night):
		var n := dark_stretch()
		cash -= Night.NIGHTLY_OVERHEAD * n
		var first := night
		night += n - 1 # _night_finish adds the last increment
		if n == 1:
			_night_finish(
				"[b]%s, Oct %d[/b]  Closed tonight: too few would come out to cover the cast. −$%.0f keeps the lights on."
				% [Calendar.DAY_NAMES[Calendar.weekday(first)], first, Night.NIGHTLY_OVERHEAD]
			)
		else:
			_night_finish(
				"[color=#8d99ae][b]%s–%s, Oct %d–%d[/b]  Dark through the week (−$%.0f overhead).[/color]"
				% [
					Calendar.DAY_NAMES[Calendar.weekday(first)],
					Calendar.DAY_NAMES[Calendar.weekday(night)],
					first,
					night,
					Night.NIGHTLY_OVERHEAD * n,
				]
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

	night += 1

	var finished := night - 1
	while reviews_shown < records.nights.size():
		var rec: Dictionary = records.nights[reviews_shown]
		if rec.night + Town.WOM_DELAY > finished:
			break
		reviews_shown += 1
		var cl := Records.claims(rec, records.built)
		if Records.salient(rec, cl):
			%NightLog.append_text(
				"[color=#e0a458]Overheard, about %s Oct %d:[/color] [i]%s[/i]\n"
				% [
					Calendar.DAY_NAMES[Calendar.weekday(rec.night)],
					rec.night,
					Records.render(rec, cl),
				]
			)

	if night <= Night.SEASON_NIGHTS and weather[night - 1] != "clear":
		line += " [color=#8d99ae]Forecast for %s: %s.[/color]" % [
			Calendar.DAY_NAMES[Calendar.weekday(night)],
			WEATHER_WORDS[weather[night - 1]],
		]
	%NightLog.append_text(line + "\n")

	if cash < Night.LOAN_LIMIT:
		%NightLog.append_text("[color=#ef5350]The bank calls your loan. Season over.[/color]\n")
		%RunButton.text = "Bankrupt: %s" % money(cash)
		%RunButton.disabled = true
		refresh()
		return
	if not lock_note_shown and night >= 2:
		lock_note_shown = true
		%NightLog.append_text("[color=#8d99ae]The building is set for the season.[/color]\n")
	if not final_week_shown and night >= FINAL_WEEK_NIGHT:
		final_week_shown = true
		%NightLog.append_text(
			"[color=#8d99ae]Final week. Whatever the town says about you now, it won't get around before Halloween.[/color]\n"
		)
	if night > Night.SEASON_NIGHTS:
		%RunButton.text = "Season over: %s" % money(cash)
		%RunButton.disabled = true
		%NightLog.append_text("[b]The season, actor by actor:[/b]\n")
		for i in records.careers:
				var c: Dictionary = records.careers[i]
				var a: Dictionary = records.roster[i]
				var card := "%s: %d screams, best night Oct %d" % [a.name, c.screams, c.best_night]
				if c.assists > 0:
						card += ", %d assists" % c.assists
				if a.observed_callouts > 0:
						card += ", called out %d times" % a.observed_callouts
				%NightLog.append_text(card + "\n")

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


func demand_for(n: int) -> int:
	return int(town.demand() * Calendar.weight_for(n) * Calendar.WEATHER[weather[n - 1]].mult)


func tonight_demand() -> int:
	return demand_for(night)


func dark_stretch() -> int:
	var n := 0
	while (
		night + n <= Night.SEASON_NIGHTS
		and Allocation.is_dark(layout, demand_for(night + n), night + n)
	):
		n += 1
	return n


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
	var assignment: Dictionary = Casting.auto_assign(layout)
	for i in layout.size():
		var b: Button = %SlotRow.get_child(i)
		var room: String = board.layout[i]
		var color: Color = ROOM_COLORS[room]
		if Casting.needs_for(layout[i]) == 0:
			b.text = slot_caption(i, assignment)
		elif room == Rooms.CORRIDOR:
			b.text = "%s\nempty" % TOOLS[layout[i]].to_upper()
		else:
			var inits := []
			for ai in board.present[i]:
				inits.append(initials(roster[ai].name))
			var lines := [TOOLS[layout[i]].to_upper()]
			if room != layout[i]:
				color = ROOM_COLORS[Rooms.PAIR_SCARE].lerp(ROOM_COLORS[Rooms.SCARE], 0.5)
				lines.append("as single")
			if inits.size() == 4:
				lines.append("%s %s" % [inits[0], inits[1]])
				lines.append("%s %s" % [inits[2], inits[3]])
			else:
				lines.append(" ".join(inits))
			b.text = "\n".join(lines)
		b.add_theme_stylebox_override("normal", slot_style(color))
		b.add_theme_stylebox_override("hover", slot_style(color.lightened(0.15)))
		b.add_theme_stylebox_override("pressed", slot_style(color.darkened(0.15)))


func _show_banner() -> void:
	var assignment: Dictionary = Casting.auto_assign(layout)
	var room_of := { }
	for room_i in assignment:
		for ai in assignment[room_i]:
			room_of[ai] = room_i

	var groups := { }
	for i in pending_absent:
		var key := consequence_key(i, room_of, assignment)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)

	var lines := []
	for key in groups:
		var rooms := { }
		for i in groups[key]:
			if room_of.has(i):
				rooms[room_of[i]] = true
		lines.append(name_list(groups[key]) + " " + consequence_line(key, rooms.size()))

	%BannerLabel.text = " ".join(lines)

	var headcount := mini(Night.actors_for(layout), roster.size())
	var bench_free := 0
	for i in range(headcount, roster.size()):
		if not pending_absent.has(i):
			bench_free += 1

	var next_up := ""
	for i in range(headcount, roster.size()):
		if not pending_absent.has(i):
			next_up = roster[i].name
			break

	var never_board: Dictionary = Casting.resolve(layout, roster, pending_absent, Casting.NEVER)
	var re_board: Dictionary = Casting.resolve(layout, roster, pending_absent, Casting.REASSIGN)
	var responds: bool = re_board.layout != never_board.layout \
			or re_board.ceilings != never_board.ceilings

	var reopened := []
	for i in layout.size():
		if never_board.layout[i] == Rooms.CORRIDOR and re_board.layout[i] != Rooms.CORRIDOR:
			reopened.append(i + 1)

	var show_gone := true
	for i in layout.size():
		if layout[i] == Rooms.ANIMATRONIC or layout[i] == Rooms.EFFECT:
			show_gone = false
		elif Casting.needs_for(layout[i]) > 0 and re_board.layout[i] != Rooms.CORRIDOR:
			show_gone = false
	%GoDarkButton.visible = show_gone
	%GoDarkButton.text = "Go dark (−$%.0f)" % Night.NIGHTLY_OVERHEAD
	%GoDarkButton.tooltip_text = "Don't open. Overhead only, and the town hears nothing about tonight."

	if bench_free > 0:
		%RespondButton.text = "Send in %s" % next_up
	elif not reopened.is_empty():
		%RespondButton.text = "Rework the board"
	else:
		%RespondButton.text = "Respond"

	%RespondButton.disabled = not responds
	if not responds:
		%RespondButton.tooltip_text = (
			"No one on call and no rework reopens anything; the hole stands."
			if bench_free == 0
			else "Sending %s in wouldn't reopen anything tonight." % next_up
		)
	elif bench_free > 0:
		%RespondButton.tooltip_text = "%s steps into the empty spot at full wage." % next_up
	else:
		%RespondButton.tooltip_text = (
			"Reopens room %d with an actor the board can spare tonight." % reopened[0]
		)

	%AcceptButton.button_pressed = true
	pending_policy = Casting.NEVER

	var goes_dark := false
	for i in layout.size():
		if Casting.needs_for(layout[i]) > 0 and never_board.layout[i] == Rooms.CORRIDOR:
			goes_dark = true
	%AcceptButton.text = "Leave it empty" if goes_dark else "Play on short"
	%AcceptButton.tooltip_text = (
		"Accept the hole; that room is empty tonight."
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
	force_open = false
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
	var group_records: Array = []
	var r: Dictionary = Night.run(
		board.layout,
		interval,
		rng,
		demand,
		Walkthrough.PRIME_SCALE,
		"",
		0.0,
		bonus_row,
		group_records,
	)
	if not records.has("built"):
		records.built = layout.duplicate()
		records.roster = roster
	var headcount := mini(Night.actors_for(layout), roster.size())
	var wage_fix := Allocation.roster_wages(roster, headcount, absent, policy) \
			- Night.wages_for(board.layout)
	var profit: float = r.profit - wage_fix
	var capacity := int(Night.NIGHT_SECONDS / interval)
	var sold_out: bool = demand / Night.GROUP_SIZE > capacity
	town.record_night(r.satisfaction)
	Records.digest(records, group_records, board, roster, night, sample_rng, town.rep, r)
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
	if WEATHER_NOTES.has(weather[night - 1]):
		line += " [color=#8d99ae]%s[/color]" % WEATHER_NOTES[weather[night - 1]]
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


func consequence_key(actor_i: int, room_of: Dictionary, assignment: Dictionary) -> String:
	if not room_of.has(actor_i):
		return "bench"
	var room_i: int = room_of[actor_i]
	var present := 0
	for ai in assignment[room_i]:
		if ai < roster.size() and not pending_absent.has(ai):
			present += 1
	if layout[room_i] == Rooms.PAIR_SCARE:
		return "pair_smaller" if present >= Night.ACTORS_PER_SCARE else "pair_dark"
	return "scare_empty" if present == 0 else "scare_solo"


func consequence_line(key: String, room_count: int) -> String:
	var forms: Array = CONSEQUENCES[key]
	if room_count <= 1:
		return forms[0]
	return forms[1] % (
		COUNT_WORDS[room_count] if room_count < COUNT_WORDS.size() else str(room_count)
	)


func slot_caption(i: int, assignment: Dictionary) -> String:
	var label: String = TOOLS[layout[i]].to_upper()
	if not assignment.has(i):
		return label
	var inits := []
	var short := false
	for ai in assignment[i]:
		if ai < roster.size():
			inits.append(initials(roster[ai].name))
		else:
			short = true
	if short:
		return "%s\nshort" % label
	if inits.size() == 4:
		return "%s\n%s %s\n%s %s" % [label, inits[0], inits[1], inits[2], inits[3]]
	return "%s\n%s" % [label, " ".join(inits)]


func name_list(group: Array) -> String:
	if group.size() == 1:
		var a: Dictionary = roster[group[0]]
		var nth: int = a.observed_callouts + 1
		if nth == 1:
			return "%s called out." % a.name
		return "%s called out again, %s time this month." % [a.name, ordinal(nth)]
	var names := []
	for i in group:
		names.append(name_tag(roster[i]))
	if names.size() == 2:
		return "%s and %s both called out." % [names[0], names[1]]
	return "%s, and %s all called out." % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


func name_tag(a: Dictionary) -> String:
	var nth: int = a.observed_callouts + 1
	return a.name if nth == 1 else "%s (%s time)" % [a.name, ordinal(nth)]


func _on_go_dark() -> void:
	force_open = false
	var names := []
	for i in pending_absent:
		roster[i].observed_callouts += 1
		names.append(roster[i].name)
	pending_absent = []
	pending_policy = Casting.NEVER
	%CalloutBanner.visible = false
	cash -= Night.NIGHTLY_OVERHEAD
	var cause: String = (
		"%s's callout gutted the show" % names[0]
		if names.size() == 1
		else "callouts gutted the show"
	)
	_night_finish(
		"[b]%s, Oct %d[/b]  Dark tonight: %s, and you kept the doors shut. −$%.0f keeps the lights on."
		% [Calendar.DAY_NAMES[Calendar.weekday(night)], night, cause, Night.NIGHTLY_OVERHEAD]
	)
