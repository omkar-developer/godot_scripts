extends Control

@export var stat_view_card : PackedScene
@export var stat_names : Array[String] = []

func _enter_tree() -> void:
	if get_parent() == null or stat_view_card == null:
		return
	if stat_names.is_empty():
		var stats =  get_parent().get_property_list()
		for stat in stats:
			if get_parent().get(stat.name) is Stat:
				stat_names.append(stat.name)
	for stat_name in stat_names:
		var card = stat_view_card.instantiate()
		var stat = get_parent().get(stat_name)
		if stat is Stat:
			card.stat = stat
			card.stat_name = stat_name
		$StatsView.add_child(card)
