class_name CardData
extends Resource

enum CardRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}


## View-only card information for UI display
## All gameplay logic lives in managers (BuffManager, WeaponManager, etc.)

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var tags: Array[String] = []
@export var rarity: CardRarity = CardRarity.COMMON
@export var category: String = ""

func _init(
	p_id: String = "",
	p_title: String = "",
	p_description: String = "",
	p_icon: Texture2D = null,
	p_tags: Array[String] = [],
	p_rarity: CardRarity = CardRarity.COMMON,
	p_category: String = ""
) -> void:
	id = p_id
	title = p_title
	description = p_description
	icon = p_icon
	tags = p_tags
	rarity = p_rarity
	category = p_category
