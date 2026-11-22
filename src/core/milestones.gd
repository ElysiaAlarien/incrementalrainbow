class_name Milestones
extends RefCounted
## The milestones that the core records and sends (see ADR-0019).
##
## A milestone is a lifetime record of something the player did: the first
## time they did it, or the highest count they reached. Each one is a whole
## number that only goes up. A milestone of a first time is 1 when it happened.
## A prestige keeps all milestones. When a milestone goes up, the core sends
## [signal Simulation.milestone_reached]. Platform achievements react to it,
## outside the core.
##
## Some milestones have one id for each item of the content, such as
## [code]factory.green[/code]. [method ids] lists each id for a content.

## The first widget sold in a market.
const FIRST_SALE := &"first_sale"
## The first factory of a color with a recipe.
const FIRST_MIXED_FACTORY := &"first_mixed_factory"
## The most factories owned at one time in one run.
const FACTORIES := &"factories"
## The first link with automatic transport.
const FIRST_AUTOMATIC_TRANSPORT := &"first_automatic_transport"
## The first warehouse.
const FIRST_WAREHOUSE := &"first_warehouse"
## The first split set.
const FIRST_SPLIT := &"first_split"
## The first community investment.
const FIRST_COMMUNITY_INVESTMENT := &"first_community_investment"
## The first research completed.
const FIRST_RESEARCH := &"first_research"
## The prisms bought across all runs.
const PRISMS_BOUGHT := &"prisms_bought"
## The prestiges done.
const PRESTIGES := &"prestiges"

## The milestones with one id for the whole game.
const SINGLE: Array[StringName] = [
	FIRST_SALE,
	FIRST_MIXED_FACTORY,
	FACTORIES,
	FIRST_AUTOMATIC_TRANSPORT,
	FIRST_WAREHOUSE,
	FIRST_SPLIT,
	FIRST_COMMUNITY_INVESTMENT,
	FIRST_RESEARCH,
	PRISMS_BOUGHT,
	PRESTIGES,
]

## The milestones that count. Each other milestone is 1 when it happened.
const COUNTS: Array[StringName] = [FACTORIES, PRISMS_BOUGHT, PRESTIGES]


## The first factory of [param color].
static func factory(color: StringName) -> StringName:
	return StringName("factory." + color)


## The first time the player has the transport tier [param tier]. The first
## tier of the content has no milestone, because each game starts with it.
static func transport_tier(tier: StringName) -> StringName:
	return StringName("transport_tier." + tier)


## The research [param research] completed.
static func research(research_id: StringName) -> StringName:
	return StringName("research." + research_id)


## The prestige upgrade [param upgrade] bought.
static func prestige_upgrade(upgrade: StringName) -> StringName:
	return StringName("prestige_upgrade." + upgrade)


## Each milestone id for [param content], as a set: id to true.
static func ids(content: Content) -> Dictionary[StringName, bool]:
	var all: Dictionary[StringName, bool] = {}
	for id in SINGLE:
		all[id] = true
	for color in content.colors():
		all[factory(color.id)] = true
	var tiers := content.transport_tiers()
	for i in range(1, tiers.size()):
		all[transport_tier(tiers[i].id)] = true
	for def in content.research():
		all[research(def.id)] = true
	for def in content.prestige_upgrades():
		all[prestige_upgrade(def.id)] = true
	return all
