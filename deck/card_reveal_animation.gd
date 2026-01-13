class_name CardRevealAnimation
extends Resource

## Base class for card reveal animations
## Create subclasses to implement different reveal styles

signal animation_completed

## Override this in subclasses to implement custom animations
func play_reveal(_card: CardView) -> void:
	push_warning("CardRevealAnimation: play_reveal() not implemented in subclass")
	animation_completed.emit()


## Helper to get reveal sound based on rarity
func get_reveal_sound(card: CardView) -> AudioStream:
	if not card.card_data:
		return card.default_reveal_sound
	
	match card.card_data.rarity:
		CardData.CardRarity.LEGENDARY:
			return card.legendary_reveal_sound if card.legendary_reveal_sound else card.default_reveal_sound
		CardData.CardRarity.EPIC:
			return card.epic_reveal_sound if card.epic_reveal_sound else card.default_reveal_sound
		CardData.CardRarity.RARE:
			return card.rare_reveal_sound if card.rare_reveal_sound else card.default_reveal_sound
		CardData.CardRarity.UNCOMMON:
			return card.uncommon_reveal_sound if card.uncommon_reveal_sound else card.default_reveal_sound
		CardData.CardRarity.COMMON:
			return card.common_reveal_sound if card.common_reveal_sound else card.default_reveal_sound
		_:
			return card.default_reveal_sound
