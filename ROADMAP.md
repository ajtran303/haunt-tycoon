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

## Milestone 2.5: telemetry and reviews

The sim computes drama and averages it away; this milestone records it and gives word of mouth a face. No balance changes, no new systems: reviews render the existing satisfaction → rep → `heard` pipeline and are never a second demand channel.

- Per-event night data: group, room, actor, hit or miss, reaction, boredom. Scare credit alternates through the room rotation, so every hit and whiff belongs to a person.
- Per-actor career records (season screams, best night, callouts) and a season-end epilogue of wrap cards.
- Everyday reviews: prose rendered from one sampled real group's walkthrough, surfacing on the `heard` delay so the lag itself becomes legible.

Exit: two tests. Conservation: per-actor attributed hits sum to the night's aggregates on every seed. Honest sampling: a review references only events its sampled group experienced. Playtest check: the open Milestone 2 legibility question (can the player say why the bad week happened) is answerable by reading reviews.

## Milestone 3: pre-season phases

Needs the Milestone 2 roster model. Audition depth is split out to Milestone 5; the casting phase here stays shallow (the auto-hired roster presented as "your casting director signed these") so this milestone stays about money and the calendar.

The phases lock in the same order reality does, hardest first: the building freezes at the marshal, the cast mostly freezes after signing (mid-season emergency hires arrive with Milestone 4's incidents), marketing never freezes. October's constraints are ones the player authored in September. The industry calendar this compresses is in DESIGN-NOTES.md.

In industry order, each locking harder than the next:

1. Build (existing blueprint editor) ending in the fire marshal: layout determines an occupancy cap, which caps line pace.
2. Casting: sign-off menu on the auto-hired roster. The pool → hire → roster model underneath is what Milestone 5 deepens.
3. Marketing: sets opening `heard` values and sells presale tickets, cash that arrives before opening night.
4. Press preview: one comped full-detail night before Oct 1. No revenue; satisfaction moves opening rep. A bought review, in Milestone 2.5 vocabulary. Skippable.

Also lands here: the season goal. Final cash needs meaning, and the loan supplies it: pay it off, or a threshold ladder (survive, profit, legend). The squeeze needs an arc to belong to.

Exit: pre-season completes in under ten minutes, with build budgeted at five (the only open-ended phase; the rest are menus). The squeeze is asserted for a reference playthrough (balanced allocation, every phase played, no skips): cash bottoms out near the loan limit right before doors open. The Milestone 0 divergence test still passes with the real phases replacing the sliders.

## Milestone 4: nightly incidents

Calendar-driven and state-driven incident templates (callout, injury, breakdown, breakthrough, a critic in the queue, a drunk swings at an actor) crossed with the Milestone 1 calendar. Each incident is a question routed through existing systems: rooms, wages, pace, rep. No new currencies. Authored one-off events come last, if at all. Green-room and breakthrough vignettes carry the crew's warmth; they are incidents too.

Exit: invariant test: accepting every default on the same seed ends visibly worse than playing the questions. Playtest check: no incident has a spreadsheet answer independent of the calendar.

## Milestone 5: audition depth

Needs Milestone 4: casting choices are bets on October, and incidents are what give October stakes.

- Skill splits into presence (how big it lands) and timing (whether it lands), mapped to two scare mechanisms: startles need resistance and can whiff; threat acts pierce depletion and close the show. The chainsaw guy goes at the end; the current model punishes that, and the model is what's wrong.
- Auditions as samples: each candidate performs one scare (one walkthrough room), a noisy draw from hidden stats. Candidates arrive in character, so the costume signals what they think they are, and the two channels can disagree. Asking price tracks reputation, not truth. Friends audition as package deals with starting rapport.
- Generalists take whatever the board assigns; owned-character specialists arrived as someone and won't fully be anyone else. Characters are entities assigned nightly at casting; specialists are the exception.
- Scare school lands here: training and scouting are actor depth.

Exit: invariant tests written before tuning: the aggregate anchors hold after the split (Milestone 0 through 3 gates stay green), and positional casting matters (best presence at the finale measurably beats anchor pairing on mean finals, deliberately inverting the Milestone 2 calibration result). Playtest check: players can say why they signed or passed on a candidate.

## Milestone 6: crew depth

- Chemistry: duo rapport on the pair-room cue (`DISTRACT_BONUS`), grown over nights worked together, partially reset on separation. Its magnitude is capped by the Milestone 2 gate: rapport must stay worth less than a dark room, or stability beats response and the gate breaks. Re-opens pull-from-pair as a real decision.
- Fatigue, only after chemistry proves the pattern: packed nights drain, rest restores, bench becomes rotation (depth's second job). Needs a floor so performance-feeds-performance can't dark-spiral.

Exit: the Milestone 2 response gate stays green with both systems on, and each system's bound (rapport cap, fatigue floor) exists as a failing invariant before its knob is touched.

## Deferred, revisit after Milestone 6

- Fast pass and midway revenue (inverts the pace tradeoff; wants Milestone 1 first).
- Late-season rule variants: lights-out nights, kid matinees (the realistic layout-reuse play).
- Theming coherence as a second quality axis (reopens the sim; needs its own case).
- Multi-season campaign: carryover, prop resale, storage costs, characters outliving actors (the lore payoff), employer reputation sizing future audition pools (only if the single-season loop sings).
