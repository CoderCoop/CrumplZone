# Changelog

All notable changes to CrumplZone, written for people using it rather than
generated from the commit log. Format follows
[Keep a Changelog](https://keepachangelog.com). There are no releases yet, so
sections are dated.

## [Unreleased]

Nothing since 0.14.1.

## [0.14.1] - 2026-08-31

### Changed

- **The city screen is a drawn map.** Water along one edge, a road grid, the
  interchange cutting across it, and a pin on each district coloured by what
  stands there. Tap a district to see the levels in it. It was a list of
  headed sections, which told you which part of town a building was in and
  showed you nothing of where that is.

## [0.14.0] - 2026-08-31

### Added

- **The levels are a city.** They are grouped into districts — a waterfront, a
  downtown, the works, an interchange, a retail park, an old town — and each
  level is in the part of town where that kind of building actually gets
  built. The sky over a level is the district's, not the seed's.
- **A run that gets harder.** Levels are ordered by how hard they measure,
  climbing across the city with steps back in it, so a hard one arrives after
  something easier rather than at the end of a treadmill.
- **Clearing a level opens the next**, and every level shows the stars earned
  on it. Progress is kept between sessions.
- **Experimental mode**, a toggle on the city screen that opens every level at
  once — for looking around without playing through first.

### Removed

- **Easy, Medium and Hard are gone.** Three hand-built curtain walls were a
  reasonable way to offer a game with three levels and a poor one for a city
  of seventeen buildings of seven kinds. Difficulty is where a level sits in
  the run now.

## [0.13.0] - 2026-08-31

### Added

- **Three new kinds of building.** A brick house with timber floors, a stepped
  gable and a chimney; a strip mall that is almost entirely shopfront glass;
  and an overpass of precast spans dropped on piers, tied to nothing — take a
  pier and its two spans drop while the rest barely notice.
- **Stone and sheet metal.** Stone is heavy and hard to break and carries a
  great deal standing still, so a stone base is something to bring a building
  down around. Sheet is almost nothing: cladding that reads as cladding.
- **Cracks show where a piece will actually break.** They are the real
  fracture lines now, not decoration — glass shows the radiating shatter it
  will make, steel the sloped face it will part on, and the pattern fills in
  as the damage mounts. You can see the break coming and decide whether it is
  the one you want.

### Fixed

- **Large panes of glass no longer shatter under their own weight.** A
  shopfront window was heavy enough that the game considered it overloaded
  just standing there, so every shop front broke while the level was still
  settling.
- **A strip mall's awning no longer sits inside its own window**, and house
  windows sit on sills instead of hanging in mid-air.

## [0.12.1] - 2026-08-28

### Fixed

- **Damage cracks stay on the piece they belong to.** A quarter of every crack
  drawn had a corner outside its own piece, the worst by 62 px — a damage line
  hanging in the air beside the thing it was meant to be damage on. It showed
  on the slivers and wedges a real demolition makes, and not on the squares
  the drawing code had been reasoned about with.

## [0.12.0] - 2026-08-28

### Added

- **Every generated level is playable.** A Levels tab lists all of them
  alongside the three named ones, each tile coloured by what the building is
  and saying what kind it is. They had been generated, measured and gated for
  a while without being reachable from anywhere in the game.
- **Next level goes on through all of them** instead of stopping at the third.

### Changed

- **One line again, and the rating is what the run cost.** Get everything
  under the line and the building is down; the stars say how much of the power
  bar it took — a third or less for three, under two thirds for two. The three
  lines and the choice to bank a win or go back for another are gone: when the
  rating is what you spent, going back for more can only make it worse.
- **The bottom of the intro screen is one Play button** naming the building it
  will start, rather than three difficulty buttons repeating a choice the
  Levels tab already offers.

## [0.11.0] - 2026-08-26

### Changed

- **How low a building can go is measured now, not guessed at.** A job in CI
  flattens every level several times and records the worst rubble it leaves.
  That number decides whether a level is fit to ship at all — a level whose
  third star sits inside its own rubble is dropped rather than shipped with a
  star nobody can earn.
- **The lines are placed by the building, not by its rubble.** How far down a
  building has been brought is a fact about the building. Previously every
  pixel of caution in the rubble estimate pushed the winning line up, toward a
  level already won on arrival. Difficulty is unchanged: three stars sits
  exactly where it did.

### Removed

- **Large-panel blocks are held back**, as load-bearing masonry was until its
  geometry was fixed. They stand perfectly well, but leave rubble 65% as tall
  as the building, which leaves no room for three lines above the pile and
  under the roof.

## [0.10.2] - 2026-08-26

### Changed

- **The shed is a building rather than a frame in mid-air.** It had walls
  nowhere on it — a row of columns holding a roof truss up, which read as a
  viaduct. It is now clad in profiled sheeting between its stanchions, with
  one bay left open as the doorway, standing on pad footings with a sill cast
  between each pair.

## [0.10.1] - 2026-08-26

### Added

- **A sixth kind of building: a load-bearing brick warehouse.** It was written
  for 0.10.0 and held back, because it sagged where the others stood still.
- **Each system is drawn as what it is.** Flat-slab columns flare where they
  meet the slab, precast panels have joints all the way round and a window
  each, shed cladding is ribbed, brick is coursed properly. The trim is not
  decoration — it is how you tell what is carrying a building before you touch
  it.

### Fixed

- **The brick warehouse stands up.** It was not settling, as it looked: parts
  of it were being built inside other parts, and what looked like a wall
  bedding down was the physics pushing them apart. Every floor overlapped the
  piers beside it, and the parapet ran through the top floor.
- **Tall flat-slab frames no longer crush their own ground floor.** Their
  columns get bigger lower down now, because there is more above them.

## [0.10.0] - 2026-08-26

### Added

- **Three lines on the level instead of one.** The lowest line is where the
  level is won; the two above it are two and three stars. Get the building
  under the first and the level offers you the choice: bank it and move on, or
  keep demolishing with the power you have left and go for the next line. The
  result screen tells you how many pixels of building still stand above it.
- **Every generated level is a different kind of building.** Five real
  structural systems, each of which stands up for a different reason and so
  has to be brought down a different way: a glazed steel frame, a large-panel
  block, a flat-slab frame, a stacked chimney, and a portal-framed shed. What
  holds a shed up is not what holds a tower up, and the tool that works on one
  is the wrong tool for the other.
- **Buildings are of a period.** The same structural system appears as
  riveted steel with brick infill, or as concrete and glass, depending on when
  it was built. It changes what things are made of, not what carries what.
- **The city behind the level matches what is being demolished.** Four
  settings — a downtown, a works, a waterfront and an estate — each with its
  own sky, skyline height and density, and lit windows. A warehouse stands in
  an industrial district before dawn, not in a glass financial one.

### Changed

- **The charge does far more damage where it lands, and costs far more to
  use.** It now flattens steel, concrete, brick and glass inside its core
  rather than cracking them, and falls off gently rather than linearly past
  that. A reinforced core still takes two of them. The bar buys about five
  full charges where it used to buy eight, so it is the tool you pick a moment
  for.
- **Stars are measured against the lines, not against par.** Par had to be
  re-measured with the solver every time the physics changed what a demolition
  costs — twice in one day, at one point. The lines are drawn from how flat
  the building can physically be left, so three stars is demanding on every
  level by construction rather than by tuning, and you can see what you are
  aiming at while you play instead of finding out at the end.

### Fixed

- **Rubble no longer wears away what it is sitting on.** A settled pile was
  still doing slow damage to solid material underneath it; it now does none.
- **A level breaks the same way every time it is loaded.** Pieces were being
  seeded from a counter that survived across rebuilds, so replaying a level
  could break it differently.

## [0.9.1] - 2026-08-26

### Fixed

- **An installed app updates itself without being closed first.** It was
  downloading each new version and then queueing it behind the app you had
  open, so it only ever switched over if you happened to close every window —
  which on a phone is close to never. Reported from an install still running
  0.7.0 with 0.9.0 long since deployed.

## [0.9.0] - 2026-08-26

### Added

- **Three levels, easy to hard**, picked from three buttons on the help screen.
  Easy is three storeys with nothing you cannot cut; medium adds a reinforced
  core to work around; hard is four storeys with two of them.
- **Ratings are measured against par** — what the best known solution for that
  level costs — instead of against a fraction of the power bar. Three stars is
  finishing within 15% of it, which means the same thing on every level rather
  than being generous on one and impossible on another. The bar itself holds
  nearly twice par, so clearing a level is the floor and the rating is the
  challenge.

### Fixed

- **Damage lines stay where they were drawn.** A piece's cracks were redrawn
  from its position, so every piece in a collapse had all of its damage lines
  jump somewhere else each time it took another hit.
- **How fast something arrives is most of the damage it does.** Load damage
  used to switch from "resting" to "full impact" at 8 px/s, so a piece drifting
  at 9 was treated like a slab arriving at 400. It now rises with the square of
  the closing speed. Rubble that has settled no longer wears away what it is
  sitting on: solid material took 13 points of damage from slow contacts over a
  collapse and now takes none. Glass still cracks under weight, which was
  always the point.
- **The top left no longer repeats what the bottom of the screen says.** The
  power number and the tool name were printed above a bar showing the power and
  a row where the chosen tool is the lit one.
- **Reset and help look like buttons**, and the app icon reads as a wrecking
  ball swinging into a building rather than a grey circle beside a yellow one.

## [0.8.0] - 2026-08-25

### Fixed

- **Things stop wearing away for holding something up.** A piece carrying a
  settled heap and a piece being hit by a falling one looked identical to the
  game, so rubble that had come to rest quietly ground down the floor beneath
  it. Measured over a full collapse, 40% of all damage from load was being
  dealt to pieces standing still — concrete carrying 702-813 against a
  tolerance of 300 while moving at under 3 px/s. Materials now carry far more
  standing still than they survive being struck with, and what does give way
  under a steady load gives way slowly. The same collapse now deals 14%, and
  none of it to concrete.
- **Glass still cracks under weight**, which was the point of the mechanism
  and is the one material with no extra margin — a pane really does fail under
  sustained load, and a pane holding up a floor is meant to.

### Changed

- **Reset and help are icon buttons.** They were words rendered at 13 px in a
  58x46 target, which is barely over the size a thumb needs. They are now 52x52
  with a drawn arrow and question mark, spaced so a thumb cannot press both,
  and styled like the tool row so the controls read as one set.
- **The game has its own icon.** The installed app, the browser tab and the
  loading screen were all still showing the stock Godot logo. They now show a
  tower with its corner knocked out and the ball that did it.

### Added

- **Updates arrive.** An installed app is served from a cache, which is what
  lets it run offline and also how it gets stuck on the version it was
  installed with. The game now notices when a newer build is waiting and
  switches to it at a moment that costs nothing — the help screen, or the start
  of a level — rather than never. It will not interrupt a level to do it.
- **Offline play**, which the installable app did not previously have: no
  service worker was ever being registered, so "install" only ever made a
  bookmark.

## [0.7.0] - 2026-08-25

### Fixed

- **The Install button now actually appears.** It never did, for two reasons
  that both had to be found by measuring. The browser fires its install offer a
  moment *after* the page loads, and the help screen asked once at startup and
  never again — so the answer was always "no". And a JavaScript `true` did not
  survive the trip across the bridge into the game, so even a well-timed answer
  read as false. The game now re-checks, and asks in a form that survives.
- **Glass ground down to slivers holds nothing up.** The smallest shards drop
  through whatever they are in and settle on the ground; nothing rests on them.
  A floor slab propped on a heap of broken glass was as wrong as it sounds —
  measured, one now falls 79 px straight through.

### Changed

- **The building has architecture.** Columns carry cap and base plates,
  floor slabs have a fascia under them and a lip on top, glazing is divided by
  a mullion and a transom, and the roof has a parapet and a plant room.
- **New tool icons.** A breaker with a T-handle and chisel, a ball on a chain
  of links hung from a hook, and a bundle of dynamite with a lit fuse. The old
  jackhammer read as a nail.

## [0.6.0] - 2026-08-25

Weight breaks things, levels end properly, and the city looks like a city.

### Added

- **Load breaks things.** A piece carrying more than it can bear cracks and
  fails, whether the weight arrived slowly or at speed. Glazing under a floor
  slab goes; a column struck hard enough goes. The numbers are measured rather
  than chosen: an untouched pane in this building carries 29, one with a floor
  resting on it carries 58, and one being landed on sees over a thousand.
- **A proper end to a level**, with a rating out of three. Clearing at all
  earns one star, a quarter of the bar left earns two, and more than half earns
  three — so the rating measures how well you played rather than whether you
  finished. Losing gets the same screen and says what is still standing.
- **The power bar shows what a hold is about to cost** before you let go: the
  segment about to be spent turns red while the rest stays amber.
- **Install it as an app from the help screen**, where the browser offers that.
  On an iPhone the same section says to use Share → Add to Home Screen, since
  Safari has no install prompt to offer.
- **Rubble gets swept up.** Slivers that come to rest below the line stop
  colliding and settle into the street as scenery. Nothing is deleted — they
  are still exactly where they fell — but they stop taking up space, which is
  what keeps a demolished building from turning into a hundred slivers of
  gravel jostling forever.

### Changed

- **Tool buttons are icons now** — a breaker, a ball on a chain, a lit charge —
  and bigger, at 66 px. The readout above still names whichever is selected.
- **The city behind the site has three layers**, with setbacks, spires and water
  tanks on the roofs, lit windows in warm and cool, haze where it meets the
  ground, and street lights throwing pools of light on the road. Pieces of the
  building have bevelled edges, and glazing has a frame and light sliding
  across it.
- **The power bar is 200** rather than 240. Once weight started breaking
  things, the level went from a seven-use solution to a three-use one, and the
  old bar made three stars a formality.

### Fixed

- **A level could sit on "settling…" for ever and never end.** Pieces thrown
  past the end of the ground fell endlessly, and a level with anything still
  moving never reports itself settled — so the win never fired. Pieces that
  leave the world are now retired where they went, and there is a time limit on
  settling as a backstop. Measured: thirty seconds after a demolition, nine
  shards were still falling at 9,100 px/s and accelerating.

## [0.5.1] - 2026-08-25

### Fixed

- **A held tool now lifts when there is nothing left to break under it**, and
  says so, instead of going silent. Holding the jackhammer on a pane after it
  had shattered did nothing at all — no blows, no animation, no message, and
  no power spent — for as long as you kept holding. Measured on the shipped
  build: four seconds of that spent 12 power and drew nothing.

## [0.5.0] - 2026-08-25

Tools are held rather than tapped, and what you spend is a bar rather than a
count of moves.

### Added

- **A power bar**, sitting directly above the tools that spend it. Every use
  takes a bite out of it and how big a bite is up to how long you hold: a tap
  is cheap and weak, a full hold is neither. When the bar runs out, so does the
  level.
- **Hold to use.** The jackhammer keeps chipping for as long as you hold it,
  a blow every fifth of a second. The wrecking ball hauls further back the
  longer you hold and swings when you let go — a longer haul is a faster swing
  and more damage, because the charge is spent on the arc rather than on a
  multiplier. The explosive packs more in and reaches further.
- **An aim preview while you hold**: where the ball would be hauled to and the
  arc it would take, or how far the blast would reach. Sliding your thumb
  before letting go moves the target, so you can change your mind without
  spending anything.

### Changed

- **Moves are gone.** Eight moves became a bar worth eight full-strength uses,
  and how you divide it is yours — around forty jackhammer blows, or eight
  charges, or any mixture.
- **The survey line is computed from each level's own material volume** rather
  than being a constant. Nothing is ever deleted, so the rubble has to fit
  under the line; a level whose line sits below its own pile is unsolvable for
  reasons no tactics can fix, and it looks exactly like a level that is merely
  hard. This matters most for generated levels, which could previously be born
  impossible with no way to tell.

## [0.4.0] - 2026-08-25

The tools are objects in the world, and things break the way things break.

### Added

- **The wrecking ball is a real wrecking ball**: a 42 kg body on a chain,
  released from the top of its arc and swung in from the side you tapped
  nearer. Tapping picks the point the bottom of the arc passes through; what it
  meets on the way is up to the building. There is no area of effect and no
  damage constant — the engine resolves the collisions, and the damage is the
  momentum the ball is carrying when it lands. Catch something early in the
  swing and it does less.
- **Real fractures.** A piece is a shape now, not a rectangle, and breaking one
  cuts it with a line. Glass comes apart in uneven slivers radiating from the
  point struck. Concrete and steel part on sloped faces, one or two per break.

### Changed

- **A broken column stops holding things up.** Halving a rectangle down the
  middle left two rectangles that stacked as well as the original did, so the
  storey above a cut column carried on standing as if nothing had happened. A
  fracture now runs at an angle, and broken faces slide over each other far
  more readily than an intact member does, so the piece above comes off its own
  stump. Measured: the slab above a cut column used to drop 1 px, and now drops
  84.
- **The survey line moved up**, from 100 px above the ground to 135. This is
  measured rather than chosen: nothing is ever deleted, so a demolished
  building has to fit under the line as rubble, and pulverised completely this
  one settles into a pile 119 px deep. The old line was asking for something
  the material volume made impossible.

## [0.3.0] - 2026-08-25

Everything in the building can be broken, and every blow shows what it did.

### Added

- **Durability, on a scale of 1 to 100.** Every piece has a number that says
  how much damage it absorbs before it comes apart: glass 1, brick 12, concrete
  24, steel 36, reinforced concrete 100. One jackhammer blow is 12 of it, so
  that reads as one blow, one blow, two, three — and nine for the reinforced
  core, which is more than any level's move budget. The intro screen lists
  them, and the numbers it shows are the numbers the game runs on.
- **A reinforced concrete core** at ground level. You will not get through it
  with the moves you have; you bring the building down around it. Two charges
  will still break it, because nothing here is invincible — some things are
  just a bad use of a move.
- **Cracks.** A piece that takes damage and survives darkens and splits
  visibly, so you can see what you have already weakened and how close it is.
- **The damage each blow does floats up from the impact**, to the side of your
  finger rather than under it.

### Changed

- **Every structural piece now comes apart into two or more pieces** when its
  durability runs out — nothing is deleted, and nothing absorbs a blow with
  nothing to show for it. A blow on rubble too small to divide is refused
  instead of costing a move.
- **Tools are quoted in the same units as durability**: the jackhammer does 12
  damage to the one piece you point at, the wrecking ball 6 to what it strikes
  squarely, and a charge 60 where you place it, falling off with distance so it
  cracks what stands around it.

## [0.2.0] - 2026-08-24

The building is made of something now, the tools show what they are doing, and
the whole thing is laid out for a phone rather than shrunk to fit one.

### Added

- **Materials, with durability.** The level is a curtain-wall office block:
  steel columns carrying concrete floor slabs, with glass glazing the bays.
  Glass breaks first and holds nothing up, concrete takes two hits, steel takes
  three. Damaged pieces darken, so you can see what you have already weakened
  before you spend another move on it. The intro screen lists what each
  material costs.
- **Animations for every tool.** The jackhammer hammers, the wrecking ball
  swings in on its chain, and the charge blows a front outwards to exactly the
  radius it reaches. They are drawn above the point you touched, not under it,
  so a thumb does not cover the feedback.
- **A place to stand.** Dusk sky, a lit city skyline behind the site, and the
  street it is being demolished on — kerb, hoarding and lane markings.

### Changed

- **The jackhammer shatters instead of halving.** It does to one piece what the
  explosive does to whatever is closest: precise, and with no collateral. Tough
  material takes more than one go, which is what makes choosing where to cut a
  decision rather than a formality.
- **The game fills the screen.** The camera frames the level for whatever shape
  of screen it is given, so the whole building is visible in portrait without
  pinching, and no part of it hides behind the readout or the controls.
- **Controls are built for thumbs.** The three tools sit in a full-width row
  along the bottom, in reach; reset and help moved to the top corner, out of the
  way of the hand. Everything is sized in real screen pixels, so a button is the
  same size on a phone as it is on a laptop — measured in a browser, at portrait
  and landscape phone sizes, not assumed.
- **The intro screen scrolls**, and Play is pinned to the bottom where it can
  always be reached — on a phone held sideways the guide used to run off the
  end of the screen with no way out of it.

## [0.1.0] - 2026-08-24

The first version with a version number. Everything below is what a player
gets, rather than each step it took to get here.

### Added

- **A game you can play in a browser**, at
  <https://codercoop.github.io/CrumplZone/>. No install, works on phones, and
  installable as a PWA. Published automatically whenever the game changes.
- **One level: a four-storey frame** that has to come down so nothing stands
  above the height line. The best single move leaves six blocks standing, and
  it can be cleared in three. You get five.
- **Three tools.** The jackhammer breaks the block you point at into two. The
  wrecking ball swings in from whichever side you clicked nearer and shoves a
  horizontal band sideways. The explosive pushes everything nearby outwards and
  shatters what is closest. Pick with the on-screen buttons or the `1`/`2`/`3`
  keys, `R` to reset. Each costs one move — they differ in what they do, not
  what they cost.
- **A misclick is free.** A tool that finds nothing to act on does not spend a
  move.
- **An intro screen** that explains the goal, what each tool does and the
  controls, and shows the version and what changed in it. It appears before
  your first move; the `?` button in the bar brings it back without losing the
  level you are part-way through.

### Fixed

- **Removing a piece now actually brings things down.** Blocks that had settled
  were falling asleep, and cutting away what held them up did not wake them, so
  the stack above hung in mid-air indefinitely. This is the reported "I remove
  pieces and nothing happens".

### Changed

- **Nothing vanishes any more.** The jackhammer breaks a block into two pieces
  and the explosive shatters what is closest, instead of deleting them. Every
  piece stays in the world and still has to end up below the line.

### Notes

- Not built yet: generated levels, scoring, undo, and sound.
- The build runs on any plain static host with no special server
  configuration. That is a deliberate constraint rather than a happy accident:
  it is what keeps the game installable as a PWA from a static host.
- Difficulty is measured rather than eyeballed. A headless search runs the move
  space on every change and fails the build if the level stops being solvable
  within its budget, or becomes solvable in a single move.
- The download is around 37 MB, which is fine on a desktop and unkind on mobile
  data. Not addressed yet.
