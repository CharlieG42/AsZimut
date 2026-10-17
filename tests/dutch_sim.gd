extends SceneTree
func _init() -> void:
	var fails: int = 0
	var rounds: int = 0
	var matches: int = 0
	for seed_value: int in 60:
		var players: int = 2 + seed_value % 4
		var names: Array[String] = []
		var flags: Array[bool] = []
		for i: int in players:
			names.append("B%d" % i)
			flags.append(true)
		var e: DutchEngine = DutchEngine.new()
		e.setup(names, flags, seed_value % 3, seed_value)
		var steps: int = 0
		while e.phase != DutchEngine.Phase.MATCH_OVER and steps < 20000:
			steps += 1
			if e.phase == DutchEngine.Phase.ROUND_OVER:
				rounds += 1
				e.start_round()
				continue
			e.bot_step()
			# conservation : 52 cartes réparties
			var total: int = e.draw_pile.size() + e.discard_pile.size() + (1 if e.held >= 0 else 0)
			for h: Array in e.hands:
				total += h.size()
			if total != 52:
				fails += 1
				print("conservation KO ", total)
				break
		if steps >= 20000:
			fails += 1
			print("bloqué seed ", seed_value)
		else:
			matches += 1
	print("matchs: %d manches: %d échecs: %d" % [matches, rounds, fails])
	quit(fails)
