class_name KillGoldLedger
extends RefCounted

var claimed_transactions: Dictionary = {}


func award(transaction_id: StringName, gold: int, is_legal_death: bool = true) -> bool:
	if transaction_id == &"" or gold <= 0 or not is_legal_death:
		return false
	if claimed_transactions.has(transaction_id):
		return false
	if not RunEconomy.add_resource(&"gold", gold):
		return false
	claimed_transactions[transaction_id] = true
	return true


func reset() -> void:
	claimed_transactions.clear()


func claimed_count() -> int:
	return claimed_transactions.size()
