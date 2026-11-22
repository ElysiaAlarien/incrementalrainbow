extends SaveMigration
## #15 adds a sell threshold to each warehouse. An older warehouse had none, so
## it gets [constant WarehouseView.NO_SELL_THRESHOLD] (-1). The new automatic
## status "held" needs no migration, because an older save never has it.


func needs() -> Array[StringName]:
	return [&"add_save_time"]


func apply(state: Dictionary) -> Dictionary:
	var warehouses: Variant = state.get("warehouses")
	if warehouses is Array:
		for warehouse: Variant in warehouses:
			if warehouse is Dictionary:
				warehouse.sell_threshold = -1
	return state
