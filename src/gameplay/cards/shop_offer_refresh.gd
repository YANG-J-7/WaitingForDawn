extends RefCounted


static func redraw(pool: Array[OpeningCardDefinition], offers: Array[OpeningCardDefinition], locked: Array[int], seed_value: int) -> void:
	var available: Array[OpeningCardDefinition] = pool.duplicate()
	for index in locked:
		available.erase(offers[index])
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for index in range(offers.size()):
		if index in locked:
			continue
		var candidates: Array[OpeningCardDefinition] = available.duplicate()
		if candidates.size() > 1:
			candidates.erase(offers[index])
		if candidates.is_empty():
			continue
		var card: OpeningCardDefinition = candidates[random.randi_range(0, candidates.size() - 1)]
		offers[index] = card
		available.erase(card)
