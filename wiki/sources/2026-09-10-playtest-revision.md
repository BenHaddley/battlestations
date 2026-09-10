# Gubgub — new-build playtest revision

User-supplied feedback, recorded 2026-09-10. This supersedes earlier inferred behavior for these features.

- Remove the upgrade tree: it adds complication without enough depth for short levels.
- During STATIONS, all trains stop. Only a selected, manually piloted train moves. BUILD TRACK hides the entire consist until the player finishes.
- Trains may use open rails: bump into buffers, pause briefly, then back out. Smooth the abrupt ninety-degree turns.
- Import the updated Steam Engine, Gunner, Chaingunner and Coal Cannon from the shared asset Drive. Engine paint variations are intentional; extra tints on offensive cars are not. All cars should fit one tile at similar sizes.
- Reduce Mail Carrier firing by 10–15%; correct its ninety-degree buffer misalignment. Preserve its random recipient per projectile.
- Spiders navigate cardinally on the board grid. Try to go around trains; otherwise grab and bite, bringing the whole train to a full stop.
- Jump Spider: jump about two tiles at once, including over trains without biting through them.
- Charger: stampede until its first car impact, deal 250 damage, stop that train, then move normally. The impacted train must accelerate again.
- Rally Spider: first spider in a wave, slightly tougher and faster than a normal spider. No aura or special support ability.
- Roller: push a separate spider egg one tile ahead. Cars prioritize the egg over its pusher. Destroying the egg releases four babies.

The Mail Carrier's randomness and the almanac were well received. The artist may supply more units and replacement UI later; those assets have not yet been promised for a specific date.

## Implementation choices requiring playtest tuning

Mail cadence is reduced 12.5%, from 3 to 2.625 envelopes per second. Buffer dwell is 0.65 seconds. Chassis and engine visible artwork has a 56-unit maximum dimension within a 65.5-unit tile. Jump travel takes 0.75 seconds. Rally has two more HP than that wave's normal spider and 15% greater speed. Junction routing prefers fresh player-built branches, then less-used exits, breaking ties in favor of going straight. These are tuning choices, not additional quoted specifications.
