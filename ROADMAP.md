# Pre-season roadmap

Goal: wrap a pre-season planning phase and an in-season ops layer around the existing sim. The sim is the match engine; it does not get retuned.

Exit criteria gate the next milestone and must be a passing test or a measurable check. Playtest checks inform but don't gate.

## Never

- No sim balance change without a failing invariant test first.
- No mid-season layout changes. Rooms are fixed once the fire marshal signs off.
- No mechanic ships without a visible cause and a player response (the legibility bar).
- At most one question per night. Quiet nights are allowed. The casting board is routine ops and does not count as the question; incidents do.
- Pre-season stays under ten minutes of play.

## Milestone 0: pivot gate

One-screen prototype. Player splits starting cash across four sliders feeding existing knobs: build budget, cast quality (actor ceiling in `Walkthrough.run`), cast depth (callout absorption, stubbed), marketing (`Town.new(starting_rep)`). Run the current 31 nights on top.

Exit: a test in `tests/` asserting, on the same seed, that build-heavy and cast-heavy allocations diverge: their nightly cash trajectories cross at least once (the lead changes hands), and neither ends the season more than 15 percent ahead in cash.

If one allocation dominates across seeds, tune the slider-to-knob mapping, not the sim; pivot only if no mapping produces divergence.

## Milestone 1: season shape

Weekend-weighted demand plus a weather forecast. October gets its real structure: dead Tuesdays, loaded Saturdays, Halloween week surge. Forecast is visible the night before.

Exit: a test asserting weekend revenue share lands in a band (60 to 75 percent of season revenue on Fri/Sat/Halloween week). Playtest check: losing a Saturday to rain hurts and the player saw it coming.

## Milestone 2: named roster and casting board

Actors become entities: skill (ceiling), wage, hidden reliability. Nightly casting board assigns actors to scare rooms; unstaffed rooms play as corridors. Callouts roll per actor per night.

Exit: invariant test on the same seed: a season that never responds to callouts ends with materially less cash than one that reassigns. Layout redundancy (spare scare rooms) measurably absorbs callouts.

## Milestone 3: pre-season phases

Needs the Milestone 2 roster model: auditions draw from it.

The phases lock in the same order reality does, hardest first: the building freezes at the marshal, the cast mostly freezes after training (mid-season emergency hires at a premium), marketing never freezes. October's constraints are ones the player authored in September. The industry calendar this compresses is in DESIGN-NOTES.md.

In industry order, each locking harder than the next:

1. Build (existing blueprint editor) ending in the fire marshal: layout determines an occupancy cap, which caps line pace.
2. Auditions: candidate pool, skill and wage visible, reliability hidden until October teaches it.
3. Scare school: optional spend to raise rookie ceilings or scout hidden reliability.
4. Marketing: sets opening `heard` values and sells presale tickets, cash that arrives before opening night.
5. Press preview: one comped full-detail night before Oct 1. No revenue; satisfaction moves opening rep with a multiplier. Skippable.

Exit: pre-season completes in under ten minutes, with build budgeted at five (the only open-ended phase; the rest are menus). The squeeze is asserted for a reference playthrough (balanced allocation, every phase played, no skips): cash bottoms out near the loan limit right before doors open. The Milestone 0 divergence test still passes with the real phases replacing the sliders.

## Milestone 4: nightly incidents

Calendar-driven and state-driven incident templates (callout, injury, breakdown, breakthrough) crossed with the Milestone 1 calendar. Each incident is a question routed through existing systems: rooms, wages, pace, rep. No new currencies. Authored one-off events come last, if at all.

Exit: invariant test: accepting every default on the same seed ends visibly worse than playing the questions. Playtest check: no incident has a spreadsheet answer independent of the calendar.

## Deferred, revisit after Milestone 4

- Fast pass and midway revenue (inverts the pace tradeoff; wants Milestone 1 first).
- Late-season rule variants: lights-out nights, kid matinees (the realistic layout-reuse play).
- Theming coherence as a second quality axis (reopens the sim; needs its own case).
- Multi-season campaign: carryover, prop resale, storage costs (only if the single-season loop sings).
