class_name AchievementTracker
extends RefCounted
## Grants platform achievements from the milestones of the core (ADR-0019).
##
## It listens to [signal Simulation.milestone_reached] and unlocks each
## achievement that a milestone grants. When it attaches to a simulation, it
## also unlocks each achievement that the milestones already grant. Thus the
## player gets the achievements of play from before this feature, of a save
## from another device, and of a time when the platform was not available.
## Offline progress is normal ticks, so its events come as in play.
##
## It does not grant what only an imported export code gave (see
## [method AchievementDef.is_earned]). A cloud save is the player's own game,
## so it grants all that its milestones grant.

var _list: AchievementList
var _service: AchievementService
var _sim: Simulation = null
## The achievements that the service took in this session, as a set.
var _sent: Dictionary[StringName, bool] = {}


func _init(p_list: AchievementList, p_service: AchievementService) -> void:
	_list = p_list
	_service = p_service
	_service.became_available.connect(sync)


## The service that this tracker unlocks achievements with.
func service() -> AchievementService:
	return _service


## Listens to [param sim] from now on, in place of the simulation before it,
## and unlocks each achievement that its milestones grant.
func attach(sim: Simulation) -> void:
	if _sim != null and _sim.milestone_reached.is_connected(_on_milestone_reached):
		_sim.milestone_reached.disconnect(_on_milestone_reached)
	_sim = sim
	_sim.milestone_reached.connect(_on_milestone_reached)
	sync()


## Unlocks each achievement that the milestones of the simulation grant.
func sync() -> void:
	if _sim == null:
		return
	var milestones := _sim.milestones()
	var imported := _sim.imported_milestones()
	for def in _list.all():
		if def.is_earned(milestones.get(def.milestone, 0), imported.get(def.milestone, 0)):
			_unlock(def)


## The game calls this once each frame.
func poll() -> void:
	_service.poll()


func _on_milestone_reached(id: StringName, value: int) -> void:
	var imported: int = _sim.imported_milestones().get(id, 0)
	for def in _list.for_milestone(id):
		if def.is_earned(value, imported):
			_unlock(def)


func _unlock(def: AchievementDef) -> void:
	if _sent.has(def.id):
		return
	if _service.unlock(def):
		_sent[def.id] = true
